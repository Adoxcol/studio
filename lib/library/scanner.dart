import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/tag_reader.dart';
import 'package:studio/providers/playable_resolver.dart';

class FolderScanner {
  FolderScanner({
    required StudioDatabase db,
    TagReader tagReader = const TagReader(),
    ArtworkStore? artwork,
  }) : _db = db,
       _tags = tagReader,
       _artwork = artwork;

  final StudioDatabase _db;
  final TagReader _tags;
  final ArtworkStore? _artwork;

  /// Re-index every folder already stored in the library.
  Future<int> rescanKnown() async {
    final folders = await _db.allFolders();
    var count = 0;
    for (final folder in folders) {
      count += await scan(folder.path);
    }
    return count;
  }

  Future<int> scan(String folderPath) async {
    final folderId = await _db.upsertFolder(folderPath);
    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      await _db.deleteTracksNotKept(folderId: folderId, keepLocators: const {});
      return 0;
    }

    var count = 0;
    final seen = <String>{};
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!_isAudio(entity.path)) continue;
      seen.add(entity.path);
      final tags = _tags.read(entity);
      String? artworkPath;
      final bytes = tags.artwork;
      if (bytes != null && _artwork != null) {
        artworkPath = await _artwork.save(bytes, mime: tags.artworkMime);
      }
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
          artworkPath: artworkPath == null
              ? const Value.absent()
              : Value(artworkPath),
          folderId: Value(folderId),
        ),
      );
      count++;
    }
    await _db.deleteTracksNotKept(folderId: folderId, keepLocators: seen);
    return count;
  }

  bool _isAudio(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return false;
    return supportedFileExtensions.contains(ext);
  }
}
