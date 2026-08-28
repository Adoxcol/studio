import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scan_progress.dart';
import 'package:studio/library/tag_reader.dart';
import 'package:studio/providers/playable_resolver.dart';

typedef ScanCancel = bool Function();
typedef ScanProgressCallback = void Function(ScanProgress progress);

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

  Future<ScanResult> rescanKnown({
    ScanCancel? isCancelled,
    ScanProgressCallback? onProgress,
  }) async {
    final folders = await _db.allFolders();
    var seen = 0;
    var written = 0;
    var skipped = 0;
    for (final folder in folders) {
      if (isCancelled?.call() ?? false) {
        return ScanResult(
          seen: seen,
          written: written,
          skipped: skipped,
          cancelled: true,
        );
      }
      final result = await scan(
        folder.path,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      seen += result.seen;
      written += result.written;
      skipped += result.skipped;
      if (result.cancelled) {
        return ScanResult(
          seen: seen,
          written: written,
          skipped: skipped,
          cancelled: true,
        );
      }
    }
    return ScanResult(seen: seen, written: written, skipped: skipped);
  }

  Future<ScanResult> scan(
    String folderPath, {
    ScanCancel? isCancelled,
    ScanProgressCallback? onProgress,
  }) async {
    final folderId = await _db.upsertFolder(folderPath);
    final label = p.basename(folderPath);
    final dir = Directory(folderPath);
    if (!dir.existsSync()) {
      await _db.deleteTracksNotKept(folderId: folderId, keepLocators: const {});
      return const ScanResult();
    }

    onProgress?.call(ScanProgress(active: true, folderLabel: label));

    final files = <File>[];
    var listed = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (isCancelled?.call() ?? false) {
        return const ScanResult(cancelled: true);
      }
      if (entity is! File) continue;
      if (!_isAudio(entity.path)) continue;
      files.add(entity);
      listed++;
      if (listed % 50 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    final existing = {
      for (final track in await _db.tracksInFolder(folderId))
        track.locator: track,
    };
    final albumsWithArt = <String>{
      for (final track in existing.values)
        if (track.artworkPath != null && (track.album ?? '').isNotEmpty)
          track.album!,
    };

    var written = 0;
    var skipped = 0;
    final seen = <String>{};

    for (var i = 0; i < files.length; i++) {
      if (isCancelled?.call() ?? false) {
        return ScanResult(
          seen: seen.length,
          written: written,
          skipped: skipped,
          cancelled: true,
        );
      }

      final file = files[i];
      seen.add(file.path);
      onProgress?.call(
        ScanProgress(
          active: true,
          folderLabel: label,
          processed: i + 1,
          total: files.length,
          skipped: skipped,
        ),
      );

      final modifiedMs = _modifiedMs(file);
      final previous = existing[file.path];
      if (previous != null &&
          previous.fileModifiedMs != null &&
          previous.fileModifiedMs == modifiedMs) {
        skipped++;
        if (i % 12 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        continue;
      }

      var tags = _tags.read(file);
      final album = tags.album;
      final needsArt =
          _artwork != null &&
          (album == null || !albumsWithArt.contains(album)) &&
          (previous?.artworkPath == null);
      if (needsArt) {
        tags = _tags.read(file, getImage: true);
      }

      String? artworkPath;
      final bytes = tags.artwork;
      if (bytes != null && _artwork != null) {
        artworkPath = await _artwork.save(bytes, mime: tags.artworkMime);
        if (artworkPath != null && album != null) {
          albumsWithArt.add(album);
        }
      }

      await _db.upsertTrack(
        TracksCompanion.insert(
          source: const Value(TrackLocator.local),
          locator: file.path,
          title: tags.title,
          artist: Value(tags.artist),
          album: Value(tags.album),
          durationMs: Value(tags.duration?.inMilliseconds),
          trackNumber: Value(tags.trackNumber),
          genre: Value(tags.genre),
          artworkPath: artworkPath == null
              ? const Value.absent()
              : Value(artworkPath),
          fileModifiedMs: Value(modifiedMs),
          folderId: Value(folderId),
        ),
      );
      written++;

      if (i % 12 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _db.deleteTracksNotKept(folderId: folderId, keepLocators: seen);
    return ScanResult(seen: seen.length, written: written, skipped: skipped);
  }

  static int _modifiedMs(File file) {
    try {
      return file.lastModifiedSync().millisecondsSinceEpoch;
    } on FileSystemException {
      return 0;
    }
  }

  bool _isAudio(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext.isEmpty) return false;
    return supportedFileExtensions.contains(ext);
  }
}
