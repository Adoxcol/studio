import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

class OfflineDownloadCancelled implements Exception {
  const OfflineDownloadCancelled();
}

class OfflineDownloadFailed implements Exception {
  const OfflineDownloadFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Lets a caller stop a download in progress.
class OfflineCancelToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// Offline copies of Subsonic songs, one folder per server account.
///
/// Files are content from the server's `download` endpoint (the original,
/// untranscoded file). A manifest per server records what is complete, so
/// half-written `.part` files are never mistaken for playable copies.
class SubsonicOfflineStore {
  SubsonicOfflineStore(this.root);

  final Directory root;
  final _manifests = <String, Map<String, _Entry>>{};

  /// Stable folder key for a server account; never contains the password.
  static String serverKey(SubsonicServerConfig config) {
    final identity =
        '${config.normalizedUrl.toLowerCase()}\n${config.username}';
    return sha1.convert(utf8.encode(identity)).toString().substring(0, 16);
  }

  Directory _dir(String server) => Directory(p.join(root.path, server));
  File _manifestFile(String server) =>
      File(p.join(_dir(server).path, 'index.json'));

  Map<String, _Entry> _manifest(String server) {
    return _manifests.putIfAbsent(server, () {
      final file = _manifestFile(server);
      if (!file.existsSync()) return {};
      try {
        final json = jsonDecode(file.readAsStringSync());
        if (json is! Map) return {};
        return {
          for (final entry in json.entries)
            '${entry.key}': ?_Entry.fromJson(entry.value),
        };
      } on Object {
        return {};
      }
    });
  }

  void _saveManifest(String server) {
    final dir = _dir(server)..createSync(recursive: true);
    final file = _manifestFile(server);
    final part = File(p.join(dir.path, 'index.json.part'));
    part.writeAsStringSync(
      jsonEncode({
        for (final entry in _manifest(server).entries)
          entry.key: entry.value.toJson(),
      }),
      flush: true,
    );
    part.renameSync(file.path);
  }

  /// The complete offline copy of [songId], if one exists on disk.
  File? fileFor(String server, String songId) {
    final entry = _manifest(server)[songId];
    if (entry == null) return null;
    final file = File(p.join(_dir(server).path, entry.fileName));
    return file.existsSync() ? file : null;
  }

  Set<String> downloadedIds(String server) => {
    for (final id in _manifest(server).keys)
      if (fileFor(server, id) != null) id,
  };

  /// Bytes used by every server's offline copies.
  int totalBytes() {
    if (!root.existsSync()) return 0;
    var total = 0;
    for (final dir in root.listSync().whereType<Directory>()) {
      final server = p.basename(dir.path);
      for (final entry in _manifest(server).values) {
        total += entry.bytes;
      }
    }
    return total;
  }

  Future<File> download({
    required String server,
    required String songId,
    required Uri uri,
    required http.Client client,
    void Function(int received, int? total)? onProgress,
    OfflineCancelToken? cancel,
  }) async {
    final dir = _dir(server)..createSync(recursive: true);
    final response = await client.send(http.Request('GET', uri));
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 ||
        type.contains('json') ||
        type.contains('xml')) {
      await response.stream.drain<void>();
      throw OfflineDownloadFailed(
        response.statusCode == 200
            ? 'The server refused the download.'
            : 'The server returned HTTP ${response.statusCode}.',
      );
    }
    final name = '${_safeId(songId)}${_extension(response)}';
    final file = File(p.join(dir.path, name));
    final part = File('${file.path}.part');
    final sink = part.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        if (cancel?.cancelled ?? false) throw const OfflineDownloadCancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, response.contentLength);
      }
      await sink.flush();
      await sink.close();
    } on Object {
      await sink.close();
      if (part.existsSync()) part.deleteSync();
      rethrow;
    }
    if (received == 0) {
      part.deleteSync();
      throw const OfflineDownloadFailed('The server sent an empty file.');
    }
    final previous = fileFor(server, songId);
    await part.rename(file.path);
    if (previous != null && previous.path != file.path) {
      _tryDelete(previous);
    }
    _manifest(server)[songId] = _Entry(fileName: name, bytes: received);
    _saveManifest(server);
    return file;
  }

  void remove(String server, Iterable<String> songIds) {
    final manifest = _manifest(server);
    var changed = false;
    for (final id in songIds) {
      final entry = manifest.remove(id);
      if (entry == null) continue;
      changed = true;
      _tryDelete(File(p.join(_dir(server).path, entry.fileName)));
    }
    if (changed) _saveManifest(server);
  }

  /// Deletes every server's offline copies.
  void removeAll() {
    _manifests.clear();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }

  static void _tryDelete(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Best effort: a file in use is left behind and overwritten later.
    }
  }

  /// Subsonic ids are opaque strings; keep them filesystem-safe.
  static String _safeId(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static const _types = {
    'audio/flac': '.flac',
    'audio/x-flac': '.flac',
    'audio/mpeg': '.mp3',
    'audio/mp3': '.mp3',
    'audio/mp4': '.m4a',
    'audio/x-m4a': '.m4a',
    'audio/aac': '.aac',
    'audio/ogg': '.ogg',
    'audio/opus': '.opus',
    'audio/wav': '.wav',
    'audio/x-wav': '.wav',
    'audio/x-aiff': '.aiff',
    'audio/aiff': '.aiff',
    'audio/x-ms-wma': '.wma',
    'audio/x-ape': '.ape',
    'audio/x-wavpack': '.wv',
    'audio/dsf': '.dsf',
  };

  static String _extension(http.StreamedResponse response) {
    final disposition = response.headers['content-disposition'] ?? '';
    final match = RegExp(
      r'''filename\*?=(?:UTF-8'')?"?([^";]+)"?''',
      caseSensitive: false,
    ).firstMatch(disposition);
    if (match != null) {
      final ext = p.extension(Uri.decodeComponent(match.group(1)!));
      if (RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(ext)) {
        return ext.toLowerCase();
      }
    }
    final type = (response.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    return _types[type] ?? '.audio';
  }
}

class _Entry {
  const _Entry({required this.fileName, required this.bytes});

  final String fileName;
  final int bytes;

  Map<String, Object> toJson() => {'file': fileName, 'bytes': bytes};

  static _Entry? fromJson(Object? json) {
    if (json is! Map) return null;
    final file = json['file'];
    final bytes = json['bytes'];
    if (file is! String || p.basename(file) != file) return null;
    return _Entry(fileName: file, bytes: bytes is int ? bytes : 0);
  }
}
