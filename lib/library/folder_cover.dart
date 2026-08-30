import 'dart:io';

import 'package:path/path.dart' as p;

/// `cover.jpg` / `folder.png` sitting next to the audio files.
abstract final class FolderCover {
  static const stems = {'cover', 'folder', 'album', 'front', 'albumart'};
  static const extensions = {'.jpg', '.jpeg', '.png', '.webp'};

  static Future<File?> find(String directory) async {
    try {
      final dir = Directory(directory);
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (!_matches(entity.path)) continue;
        if (await entity.length() > 0) return entity;
      }
    } on FileSystemException {
      return null;
    }
    return null;
  }

  static bool _matches(String path) {
    final ext = p.extension(path).toLowerCase();
    if (!extensions.contains(ext)) return false;
    final stem = p.basenameWithoutExtension(path).toLowerCase();
    return stems.contains(stem);
  }
}
