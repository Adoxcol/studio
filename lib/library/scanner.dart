import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/cover_art_lookup.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/folder_cover.dart';
import 'package:studio/library/library_query.dart';
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
    CoverArtLookup? covers,
  }) : _db = db,
       _tags = tagReader,
       _artwork = artwork,
       _covers = covers;

  static const _writeBatch = 24;

  final StudioDatabase _db;
  final TagReader _tags;
  final ArtworkStore? _artwork;
  final CoverArtLookup? _covers;

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
    final albumArt = <String, String>{};
    final dirArt = <String, String>{};
    for (final track in existing.values) {
      _rememberArt(
        track.artworkPath,
        track.album,
        track.locator,
        albumArt,
        dirArt,
      );
    }

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
        albumArt: albumArt,
        dirArt: dirArt,
      );
      dirty.clear();
    }

    for (var i = 0; i < files.length; i++) {
      if (isCancelled?.call() ?? false) {
        await flush();
        await _fillMissingArtwork(
          folderId,
          albumArt: albumArt,
          dirArt: dirArt,
          isCancelled: isCancelled,
        );
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
          previous.fileModifiedMs == file.modifiedMs &&
          previous.year != null) {
        skipped++;
        continue;
      }

      dirty.add(file);
      if (dirty.length >= _writeBatch) {
        await flush();
      }
    }

    await flush();
    await _fillMissingArtwork(
      folderId,
      albumArt: albumArt,
      dirArt: dirArt,
      isCancelled: isCancelled,
    );
    await _db.deleteTracksNotKept(folderId: folderId, keepLocators: seen);
    return ScanResult(seen: seen.length, written: written, skipped: skipped);
  }

  Future<int> _writeDirty(
    List<_AudioFile> dirty, {
    required int folderId,
    required Map<String, Track> existing,
    required Map<String, String> albumArt,
    required Map<String, String> dirArt,
  }) async {
    final tagsList = await _readAll([
      for (final file in dirty) file.path,
    ], getImage: false);

    final rows = <TracksCompanion>[];
    for (var i = 0; i < dirty.length; i++) {
      final file = dirty[i];
      var tags = tagsList[i];
      final previous = existing[file.path];
      final albumKey = _albumKey(tags.album);
      final dirKey = p.dirname(file.path).toLowerCase();
      final needsArt =
          _artwork != null &&
          previous?.artworkPath == null &&
          (albumKey == null || !albumArt.containsKey(albumKey)) &&
          !dirArt.containsKey(dirKey);
      if (needsArt) {
        tags = _tags.read(File(file.path), getImage: true);
      }

      String? artworkPath;
      final bytes = tags.artwork;
      if (bytes != null && _artwork != null) {
        artworkPath = await _artwork.save(bytes, mime: tags.artworkMime);
      }
      artworkPath ??=
          previous?.artworkPath ??
          (albumKey == null ? null : albumArt[albumKey]) ??
          dirArt[dirKey];
      _rememberArt(artworkPath, tags.album, file.path, albumArt, dirArt);

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
          year: Value(tags.year ?? 0),
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

  Future<void> _fillMissingArtwork(
    int folderId, {
    required Map<String, String> albumArt,
    required Map<String, String> dirArt,
    ScanCancel? isCancelled,
  }) async {
    final rows = await _db.tracksInFolder(folderId);
    for (final track in rows) {
      _rememberArt(
        track.artworkPath,
        track.album,
        track.locator,
        albumArt,
        dirArt,
      );
    }

    final sidecarCache = <String, String?>{};
    final updates = <int, String>{};
    for (final track in rows) {
      if (isCancelled?.call() ?? false) return;
      if (track.artworkPath != null) continue;
      final dirKey = p.dirname(track.locator).toLowerCase();
      var path = dirArt[dirKey];
      path ??= await _sidecarPath(track.locator, sidecarCache, dirArt);
      final albumKey = _albumKey(track.album);
      path ??= albumKey == null ? null : albumArt[albumKey];
      if (path != null) {
        updates[track.id] = path;
        _rememberArt(path, track.album, track.locator, albumArt, dirArt);
      }
    }
    if (updates.isNotEmpty) {
      await _db.setArtworkPaths(updates);
    }
    if (isCancelled?.call() ?? false) return;
    await _fetchMissingCovers(folderId, isCancelled: isCancelled);
  }

  Future<String?> _sidecarPath(
    String locator,
    Map<String, String?> cache,
    Map<String, String> dirArt,
  ) async {
    if (_artwork == null) return null;
    final dir = p.dirname(locator);
    final key = dir.toLowerCase();
    if (cache.containsKey(key)) return cache[key];
    final file = FolderCover.find(dir);
    if (file == null) {
      cache[key] = null;
      return null;
    }
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      cache[key] = null;
      return null;
    }
    final saved = await _artwork.save(bytes, mime: p.extension(file.path));
    cache[key] = saved;
    if (saved != null) dirArt[key] = saved;
    return saved;
  }

  Future<void> _fetchMissingCovers(
    int folderId, {
    ScanCancel? isCancelled,
  }) async {
    if (_covers == null || _artwork == null) return;
    final rows = await _db.tracksInFolder(folderId);
    final groups = <String, List<Track>>{};
    for (final track in rows) {
      if (track.artworkPath != null) continue;
      final album = track.album?.trim();
      if (album == null || album.isEmpty) continue;
      if (album.toLowerCase() == LibraryQuery.unknownAlbum.toLowerCase()) {
        continue;
      }
      final artist = LibraryQuery.firstCreditedArtist(track.artist ?? '');
      if (artist == LibraryQuery.unknownArtist) continue;
      final key = '${artist.toLowerCase()}\u0001${album.toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(track);
    }

    final updates = <int, String>{};
    for (final group in groups.values) {
      if (isCancelled?.call() ?? false) break;
      final sample = group.first;
      final bytes = await _covers.fetch(
        artist: LibraryQuery.firstCreditedArtist(sample.artist ?? ''),
        album: sample.album!.trim(),
      );
      if (bytes == null || bytes.isEmpty) continue;
      final path = await _artwork.save(bytes);
      if (path == null) continue;
      for (final track in group) {
        updates[track.id] = path;
      }
    }
    await _db.setArtworkPaths(updates);
  }

  static void _rememberArt(
    String? artworkPath,
    String? album,
    String locator,
    Map<String, String> albumArt,
    Map<String, String> dirArt,
  ) {
    if (artworkPath == null) return;
    final albumKey = _albumKey(album);
    if (albumKey != null) {
      albumArt.putIfAbsent(albumKey, () => artworkPath);
    }
    dirArt.putIfAbsent(p.dirname(locator).toLowerCase(), () => artworkPath);
  }

  static String? _albumKey(String? album) {
    final trimmed = album?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
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
