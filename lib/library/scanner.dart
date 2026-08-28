import 'dart:io';
import 'dart:isolate';

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

  static const _writeBatch = 24;

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

    final files = await _listAudioFiles(folderPath);
    if (isCancelled?.call() ?? false) {
      return const ScanResult(cancelled: true);
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
    final dirty = <_AudioFile>[];

    Future<void> flush() async {
      if (dirty.isEmpty) return;
      written += await _writeDirty(
        dirty,
        folderId: folderId,
        existing: existing,
        albumsWithArt: albumsWithArt,
      );
      dirty.clear();
    }

    for (var i = 0; i < files.length; i++) {
      if (isCancelled?.call() ?? false) {
        await flush();
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

      final previous = existing[file.path];
      if (previous != null &&
          previous.fileModifiedMs != null &&
          previous.fileModifiedMs == file.modifiedMs) {
        skipped++;
        continue;
      }

      dirty.add(file);
      if (dirty.length >= _writeBatch) {
        await flush();
      }
    }

    await flush();
    await _db.deleteTracksNotKept(folderId: folderId, keepLocators: seen);
    return ScanResult(seen: seen.length, written: written, skipped: skipped);
  }

  Future<int> _writeDirty(
    List<_AudioFile> dirty, {
    required int folderId,
    required Map<String, Track> existing,
    required Set<String> albumsWithArt,
  }) async {
    final tagsList = await _readAll([
      for (final file in dirty) file.path,
    ], getImage: false);

    final rows = <TracksCompanion>[];
    for (var i = 0; i < dirty.length; i++) {
      final file = dirty[i];
      var tags = tagsList[i];
      final previous = existing[file.path];
      final album = tags.album;
      final needsArt =
          _artwork != null &&
          (album == null || !albumsWithArt.contains(album)) &&
          (previous?.artworkPath == null);
      if (needsArt) {
        tags = _tags.read(File(file.path), getImage: true);
      }

      String? artworkPath;
      final bytes = tags.artwork;
      if (bytes != null && _artwork != null) {
        artworkPath = await _artwork.save(bytes, mime: tags.artworkMime);
        if (artworkPath != null && album != null) {
          albumsWithArt.add(album);
        }
      }

      rows.add(
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
          fileModifiedMs: Value(file.modifiedMs),
          folderId: Value(folderId),
        ),
      );
    }

    await _db.upsertTracks(rows);
    return rows.length;
  }

  Future<List<ParsedTags>> _readAll(
    List<String> paths, {
    required bool getImage,
  }) async {
    if (paths.isEmpty) return const [];
    if (_tags.runtimeType != TagReader || paths.length < 8) {
      return [
        for (final path in paths) _tags.read(File(path), getImage: getImage),
      ];
    }
    return Isolate.run(() {
      const reader = TagReader();
      return [
        for (final path in paths) reader.read(File(path), getImage: getImage),
      ];
    });
  }
}

class _AudioFile {
  const _AudioFile({required this.path, required this.modifiedMs});

  final String path;
  final int modifiedMs;
}

Future<List<_AudioFile>> _listAudioFiles(String folderPath) {
  return Isolate.run(() => _listAudioFilesSync(folderPath));
}

List<_AudioFile> _listAudioFilesSync(String folderPath) {
  final dir = Directory(folderPath);
  final files = <_AudioFile>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!_isAudioPath(entity.path)) continue;
    files.add(_AudioFile(path: entity.path, modifiedMs: _modifiedMs(entity)));
  }
  return files;
}

int _modifiedMs(File file) {
  try {
    return file.lastModifiedSync().millisecondsSinceEpoch;
  } on FileSystemException {
    return 0;
  }
}

bool _isAudioPath(String path) {
  final ext = p.extension(path).toLowerCase();
  if (ext.isEmpty) return false;
  return supportedFileExtensions.contains(ext);
}
