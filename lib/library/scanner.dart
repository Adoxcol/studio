import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/database.dart';
import 'package:studio/library/tag_reader.dart';
import 'package:studio/providers/playable_resolver.dart';

class FolderScanner {
  FolderScanner({
    required StudioDatabase db,
    TagReader tagReader = const TagReader(),
  }) : _db = db,
       _tags = tagReader;

  final StudioDatabase _db;
  final TagReader _tags;

  Future<int> scan(String folderPath) async {
    final folderId = await _db.upsertFolder(folderPath);
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return 0;

    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!_isAudio(entity.path)) continue;
      final tags = _tags.read(entity);
      await _db.upsertTrack(
        TracksCompanion.insert(
          source: const Value(TrackLocator.local),
          locator: entity.path,
          title: tags.title,
          artist: Value(tags.artist),
          album: Value(tags.album),
          durationMs: Value(tags.duration?.inMilliseconds),
          trackNumber: Value(tags.trackNumber),
          genre: Value(tags.genre),
          folderId: Value(folderId),
        ),
      );
      count++;
    }
    return count;
  }

  bool _isAudio(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return false;
    return supportedFileExtensions.contains(ext);
  }
}
