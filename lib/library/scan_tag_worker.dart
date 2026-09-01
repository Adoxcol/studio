import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/folder_cover.dart';
import 'package:studio/library/tag_reader.dart';

class ScannedTags {
  const ScannedTags(this.tags, this.artworkPath);
  final ParsedTags tags;
  final String? artworkPath;
}

/// Read/save one picture at a time. Returned metadata deliberately has no image
/// bytes, so neither a scan batch nor the main isolate retains embedded covers.
Future<List<ScannedTags>> readAndCacheTags(
  List<String> paths,
  TagReader reader,
  ArtworkStore? artwork,
) async {
  final result = <ScannedTags>[];
  for (final path in paths) {
    final tags = reader.read(File(path), getImage: artwork != null);
    final image = tags.artwork;
    final saved = tags.readSucceeded && image != null && artwork != null
        ? await artwork.save(image, mime: tags.artworkMime)
        : null;
    result.add(
      ScannedTags(
        ParsedTags(
          title: tags.title,
          artist: tags.artist,
          album: tags.album,
          duration: tags.duration,
          sampleRateHz: tags.sampleRateHz,
          trackNumber: tags.trackNumber,
          genre: tags.genre,
          year: tags.year,
          readSucceeded: tags.readSucceeded,
        ),
        saved,
      ),
    );
  }
  return result;
}

Future<String?> cacheSidecar(String locator, ArtworkStore? artwork) async {
  if (artwork == null) return null;
  final file = FolderCover.find(p.dirname(locator));
  if (file == null) return null;
  try {
    return await artwork.save(
      await file.readAsBytes(),
      mime: p.extension(file.path),
    );
  } on FileSystemException {
    return null;
  }
}

/// A scan-scoped, sequential worker reused across all batches. Only one request
/// can be in flight; no unbounded queue of image buffers can accumulate.
class ScanTagWorker {
  ScanTagWorker._(this._port) : _events = StreamIterator(_port);
  final ReceivePort _port;
  final StreamIterator<dynamic> _events;
  Isolate? _isolate;
  late final SendPort _commands;
  bool _busy = false;
  bool _closed = false;

  static Future<ScanTagWorker> start(String? artworkDirectory) async {
    final worker = ScanTagWorker._(ReceivePort());
    try {
      worker._isolate = await Isolate.spawn(
        _run,
        (worker._port.sendPort, artworkDirectory),
        onError: worker._port.sendPort,
        onExit: worker._port.sendPort,
        debugName: 'studio-scan-tags',
      );
      worker._commands = await worker._next() as SendPort;
      return worker;
    } catch (_) {
      await worker.close();
      rethrow;
    }
  }

  Future<List<ScannedTags>> read(List<String> paths) async =>
      await _request(('read', paths)) as List<ScannedTags>;

  Future<String?> sidecar(String locator) async =>
      await _request(('sidecar', locator)) as String?;

  Future<String?> save(Uint8List bytes) async =>
      await _request(('save', TransferableTypedData.fromList([bytes])))
          as String?;

  Future<Object?> _request((String, Object) request) async {
    if (_closed) throw StateError('Scan worker is closed');
    if (_busy) throw StateError('Scan worker requests must be sequential');
    _busy = true;
    try {
      _commands.send(request);
      final reply = await _next() as _Reply;
      if (reply.error != null) {
        throw RemoteError(reply.error!, reply.stack ?? '');
      }
      return reply.value;
    } finally {
      _busy = false;
    }
  }

  Future<Object?> _next() async {
    if (!await _events.moveNext() || _events.current == null) {
      throw StateError('Scan worker exited before replying');
    }
    final message = _events.current;
    if (message is List && message.length == 2) {
      throw RemoteError('${message[0]}', '${message[1]}');
    }
    return message;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _port.close();
    await _events.cancel();
  }

  static Future<void> _run((SendPort, String?) setup) async {
    final commands = ReceivePort();
    final output = setup.$1;
    final artwork = setup.$2 == null
        ? null
        : ArtworkStore(Directory(setup.$2!));
    output.send(commands.sendPort);
    await for (final message in commands) {
      final request = message as (String, Object);
      try {
        final Object? value = switch (request.$1) {
          'read' => await readAndCacheTags(
            request.$2 as List<String>,
            const TagReader(),
            artwork,
          ),
          'sidecar' => await cacheSidecar(request.$2 as String, artwork),
          'save' => await artwork?.save(
            (request.$2 as TransferableTypedData).materialize().asUint8List(),
          ),
          _ => throw StateError('Unknown scan worker request'),
        };
        output.send(_Reply(value));
      } catch (error, stack) {
        output.send(_Reply(null, error: '$error', stack: '$stack'));
      }
    }
  }
}

class _Reply {
  const _Reply(this.value, {this.error, this.stack});
  final Object? value;
  final String? error;
  final String? stack;
}
