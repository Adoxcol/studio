import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Subsonic signs every request with a fresh random salt (`s`) and token
/// (`t`), so each track of an album gets its own cover URL. Dropping them
/// makes the URL identify the image, not the request.
String stableArtworkKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasQuery) return url;
  final params = Map.of(uri.queryParameters)
    ..remove('s')
    ..remove('t');
  return uri.replace(queryParameters: params).toString();
}

/// Downloads remote artwork once and keeps it on disk across launches.
class NetworkArtworkCache {
  NetworkArtworkCache({
    this.directory,
    http.Client? client,
    this.maxBytes = 256 * 1024 * 1024,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  /// The app-wide cache. Without a [directory] (tests, previews) artwork is
  /// still shared in memory through Flutter's image cache.
  static NetworkArtworkCache instance = NetworkArtworkCache();

  final Directory? directory;
  final int maxBytes;
  final Duration timeout;
  final http.Client _client;
  final _inFlight = <String, Future<Uint8List>>{};

  File? _fileFor(String key) {
    final dir = directory;
    if (dir == null) return null;
    return File(p.join(dir.path, md5.convert(key.codeUnits).toString()));
  }

  /// Bytes for [url], from disk when cached. Concurrent calls for the same
  /// image share one download.
  Future<Uint8List> bytes(String url) {
    final key = stableArtworkKey(url);
    // A block body: returning the removed future would make it await itself.
    return _inFlight[key] ??= _load(url, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<Uint8List> _load(String url, String key) async {
    final file = _fileFor(key);
    if (file != null) {
      try {
        final cached = await file.readAsBytes();
        if (cached.isNotEmpty) return cached;
      } on FileSystemException {
        // Not cached yet.
      }
    }
    final response = await _client.get(Uri.parse(url)).timeout(timeout);
    final body = response.bodyBytes;
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 || body.isEmpty || type.contains('json')) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.parse(key),
      );
    }
    if (file != null) await _store(file, body);
    return body;
  }

  Future<void> _store(File file, Uint8List body) async {
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(body, flush: true);
      await temp.rename(file.path);
    } on FileSystemException catch (error) {
      debugPrint('Artwork cache write failed: $error');
    }
  }

  /// Deletes the least recently written files once the cache is over
  /// [maxBytes], down to three quarters of it.
  Future<void> prune() async {
    final dir = directory;
    if (dir == null || !await dir.exists()) return;
    final files = <(File, FileStat)>[];
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add((entity, stat));
      total += stat.size;
    }
    if (total <= maxBytes) return;
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    final target = maxBytes * 3 ~/ 4;
    for (final (file, stat) in files) {
      if (total <= target) break;
      try {
        await file.delete();
        total -= stat.size;
      } on FileSystemException {
        // In use or already gone.
      }
    }
  }
}

/// Remote artwork that shares one cache entry per image, not per signed URL,
/// and is kept on disk by [NetworkArtworkCache].
@immutable
class NetworkArtworkImage extends ImageProvider<NetworkArtworkImage> {
  NetworkArtworkImage(this.url, {NetworkArtworkCache? cache})
    : key = stableArtworkKey(url),
      _cache = cache;

  final String url;

  /// Identity of the image; the URL minus its per-request signature.
  final String key;
  final NetworkArtworkCache? _cache;

  @override
  Future<NetworkArtworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    NetworkArtworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _decode(decode),
      scale: 1,
      debugLabel: key.key,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
      ],
    );
  }

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async {
    final cache = _cache ?? NetworkArtworkCache.instance;
    final bytes = await cache.bytes(url);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is NetworkArtworkImage && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'NetworkArtworkImage("$key")';
}
