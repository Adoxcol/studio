import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Writes embedded cover art to a content-addressed file cache.
class ArtworkStore {
  ArtworkStore(this.directory);

  final Directory directory;

  Future<String?> save(Uint8List bytes, {String? mime}) async {
    if (bytes.isEmpty) return null;
    await directory.create(recursive: true);
    final name = '${_fingerprint(bytes)}${_extension(bytes, mime)}';
    final file = File(p.join(directory.path, name));
    if (file.existsSync()) return file.path;
    // Scan worker isolates can save the same cover at the same time, so each
    // write gets its own temp file. The name is content-addressed: if another
    // writer lands the file first, its bytes are identical and ours can go.
    final part = File('${file.path}.${_tempSuffix()}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
      if (file.existsSync()) return file.path;
      await part.rename(file.path);
    } on FileSystemException {
      if (!file.existsSync()) rethrow;
    } finally {
      if (part.existsSync()) {
        try {
          part.deleteSync();
        } on FileSystemException {
          // Best effort; a stray temp file is harmless.
        }
      }
    }
    return file.path;
  }

  static final _random = Random();

  static String _tempSuffix() =>
      '$pid-${_random.nextInt(1 << 32).toRadixString(16)}';

  static String _extension(Uint8List bytes, String? mime) {
    final lower = mime?.toLowerCase() ?? '';
    if (lower.contains('png')) return '.png';
    if (lower.contains('webp')) return '.webp';
    if (lower.contains('gif')) return '.gif';
    if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      return '.png';
    }
    return '.jpg';
  }

  static String _fingerprint(Uint8List bytes) {
    var hash = 0x811c9dc5;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${bytes.length.toRadixString(16)}_${hash.toRadixString(16)}';
  }
}
