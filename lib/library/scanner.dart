import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/cover_art_lookup.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scan_tag_worker.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/library/scan_progress.dart';
import 'package:studio/library/tag_reader.dart';
import 'package:studio/providers/playable_resolver.dart';

typedef ScanCancel = bool Function();
typedef ScanProgressCallback = void Function(ScanProgress progress);
typedef _AlbumKey = (String, String);

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
    final allTracks = await _db.allTracks();
    final tracksByFolder = <int, List<Track>>{};
    for (final track in allTracks) {
      if (track.folderId != null) {
        tracksByFolder.putIfAbsent(track.folderId!, () => []).add(track);
      }
    }

    var seen = 0;
    var written = 0;
    var skipped = 0;
    var unavailable = 0;
    for (final folder in folders) {
      if (isCancelled?.call() ?? false) {
        return ScanResult(
          seen: seen,
          written: written,
          skipped: skipped,
          cancelled: true,
          unavailableFolders: unavailable,
        );
      }
      final result = await scan(
        folder.path,
        knownFolderId: folder.id,
        knownTracks: tracksByFolder[folder.id] ?? const [],
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      seen += result.seen;
      written += result.written;
      skipped += result.skipped;
      unavailable += result.unavailableFolders;
      if (result.cancelled) {
        return ScanResult(
          seen: seen,
          written: written,
          skipped: skipped,
          cancelled: true,
          unavailableFolders: unavailable,
        );
      }
    }
    return ScanResult(
      seen: seen,
      written: written,
      skipped: skipped,
      unavailableFolders: unavailable,
    );
  }

  Future<ScanResult> scan(
    String folderPath, {
    int? knownFolderId,
    List<Track>? knownTracks,
    ScanCancel? isCancelled,
    ScanProgressCallback? onProgress,
  }) async {
    final folderId = knownFolderId ?? await _db.upsertFolder(folderPath);
    final label = p.basename(folderPath);
    onProgress?.call(ScanProgress(active: true, folderLabel: label));

    final List<_AudioFile> files;
    try {
      // Enumeration must finish successfully before absence can mean deletion.
      files = await _listAudioFiles(folderPath);
    } on FileSystemException catch (error) {
      debugPrint(
        '[Library scan] Folder unavailable; keeping saved tracks and playlists: $folderPath ($error)',
      );
      return const ScanResult(unavailableFolders: 1);
    }
    if (isCancelled?.call() ?? false) {
      return const ScanResult(cancelled: true);
    }

    final session = _ScanSession(_tags, _artwork);
    try {
      final existingList = knownTracks ?? await _db.tracksInFolder(folderId);
      final existing = {for (final track in existingList) track.locator: track};
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
          session: session,
        );
        dirty.clear();
      }

      for (var i = 0; i < files.length; i++) {
        if (isCancelled?.call() ?? false) {
          await flush();
          await _fillMissingArtwork(
            folderId,
            session: session,
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
        session: session,
        isCancelled: isCancelled,
      );
      if (isCancelled?.call() ?? false) {
        return ScanResult(
          seen: seen.length,
          written: written,
          skipped: skipped,
          cancelled: true,
        );
      }
      if (!await Directory(folderPath).exists()) {
        return ScanResult(
          seen: seen.length,
          written: written,
          skipped: skipped,
          unavailableFolders: 1,
        );
      }
      await _db.deleteTracksNotKept(folderId: folderId, keepLocators: seen);
      return ScanResult(seen: seen.length, written: written, skipped: skipped);
    } finally {
      await session.close();
    }
  }

  Future<int> _writeDirty(
    List<_AudioFile> dirty, {
    required int folderId,
    required Map<String, Track> existing,
    required _ScanSession session,
  }) async {
    final tagsList = await session.read([for (final file in dirty) file.path]);

    final rows = <TracksCompanion>[];
    for (var i = 0; i < dirty.length; i++) {
      final file = dirty[i];
      final prepared = tagsList[i];
      final tags = prepared.tags;
      final previous = existing[file.path];
      if (!tags.readSucceeded) {
        // Keep prior metadata/artwork, but invalidate the successful-read stamp
        // so a restart or an unchanged mtime cannot suppress recovery.
        rows.add(
          TracksCompanion.insert(
            locator: file.path,
            title: previous?.title ?? tags.title,
            folderId: Value(folderId),
            fileModifiedMs: const Value(null),
          ),
        );
        debugPrint(
          '[Library scan] Tag read failed; preserving metadata and retrying on next scan: ${file.path}',
        );
        continue;
      }

      String? artworkPath = prepared.artworkPath;
      // Each changed file's embedded picture is authoritative. Sharing happens
      // only after all dirty rows have been read, never instead of reading them.
      if (_artwork == null) artworkPath ??= previous?.artworkPath;

      rows.add(
        TracksCompanion.insert(
          source: const Value(TrackLocator.local),
          locator: file.path,
          title: tags.title,
          artist: Value(tags.artist),
          album: Value(tags.album),
          durationMs: Value(tags.duration?.inMilliseconds),
          fileSizeBytes: Value(file.sizeBytes),
          sampleRateHz: Value(tags.sampleRateHz),
          trackNumber: Value(tags.trackNumber),
          genre: Value(tags.genre),
          year: Value(tags.year ?? 0),
          artworkPath: Value(artworkPath),
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
    required _ScanSession session,
    ScanCancel? isCancelled,
  }) async {
    final rows = await _db.tracksInFolder(folderId);
    final albumArt = <_AlbumKey, String>{};
    for (final track in rows) {
      if (track.fileModifiedMs == null) continue;
      final key = _albumKey(track.artist, track.album);
      final art = track.artworkPath;
      if (key != null && art != null) albumArt.putIfAbsent(key, () => art);
    }

    final sidecarCache = <String, String?>{};
    final updates = <int, String>{};
    for (final track in rows) {
      if (isCancelled?.call() ?? false) return;
      if (track.artworkPath != null || track.fileModifiedMs == null) continue;
      var path = await _sidecarPath(track.locator, sidecarCache, session);
      final albumKey = _albumKey(track.artist, track.album);
      path ??= albumKey == null ? null : albumArt[albumKey];
      if (path != null) {
        updates[track.id] = path;
        if (albumKey != null) albumArt.putIfAbsent(albumKey, () => path!);
      }
    }
    if (updates.isNotEmpty) {
      await _db.setArtworkPaths(updates);
    }
    if (isCancelled?.call() ?? false) return;
    await _fetchMissingCovers(
      folderId,
      session: session,
      isCancelled: isCancelled,
    );
  }

  Future<String?> _sidecarPath(
    String locator,
    Map<String, String?> cache,
    _ScanSession session,
  ) async {
    if (_artwork == null) return null;
    final dir = p.dirname(locator);
    final key = p.normalize(dir);
    if (cache.containsKey(key)) return cache[key];
    final saved = await session.sidecar(locator);
    cache[key] = saved;
    return saved;
  }

  Future<void> _fetchMissingCovers(
    int folderId, {
    required _ScanSession session,
    ScanCancel? isCancelled,
  }) async {
    if (_covers == null || _artwork == null) return;
    final rows = await _db.tracksInFolder(folderId);
    final groups = <_AlbumKey, List<Track>>{};
    for (final track in rows) {
      if (track.artworkPath != null || track.fileModifiedMs == null) continue;
      final album = track.album?.trim();
      if (album == null || album.isEmpty) continue;
      if (album.toLowerCase() == LibraryQuery.unknownAlbum.toLowerCase()) {
        continue;
      }
      final artist = LibraryQuery.firstCreditedArtist(track.artist ?? '');
      if (artist == LibraryQuery.unknownArtist) continue;
      final key = _albumKey(track.artist, album);
      if (key == null) continue;
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
      final path = await session.save(bytes);
      if (path == null) continue;
      for (final track in group) {
        updates[track.id] = path;
      }
    }
    await _db.setArtworkPaths(updates);
  }

  static _AlbumKey? _albumKey(String? artist, String? album) {
    final who = artist?.trim().toLowerCase();
    final title = album?.trim().toLowerCase();
    if (who == null ||
        who.isEmpty ||
        title == null ||
        title.isEmpty ||
        who == LibraryQuery.unknownArtist.toLowerCase() ||
        title == LibraryQuery.unknownAlbum.toLowerCase()) {
      return null;
    }
    return (who, title);
  }
}

/// Production reads/hash/file IO stay in one lazy worker. Injected readers and
/// stores keep their test/application-specific behavior in the calling isolate.
class _ScanSession {
  _ScanSession(this.reader, this.artwork);
  final TagReader reader;
  final ArtworkStore? artwork;
  ScanTagWorker? _worker;
  bool get _useWorker =>
      reader.runtimeType == TagReader &&
      (artwork == null || artwork.runtimeType == ArtworkStore);

  Future<ScanTagWorker> _getWorker() async =>
      _worker ??= await ScanTagWorker.start(artwork?.directory.path);

  Future<List<ScannedTags>> read(List<String> paths) async => _useWorker
      ? (await _getWorker()).read(paths)
      : readAndCacheTags(paths, reader, artwork);

  Future<String?> sidecar(String locator) async => _useWorker
      ? (await _getWorker()).sidecar(locator)
      : cacheSidecar(locator, artwork);

  Future<String?> save(Uint8List bytes) async =>
      _useWorker ? (await _getWorker()).save(bytes) : artwork?.save(bytes);

  Future<void> close() async => _worker?.close();
}

class _AudioFile {
  const _AudioFile({
    required this.path,
    required this.modifiedMs,
    required this.sizeBytes,
  });

  final String path;
  final int? modifiedMs;
  final int? sizeBytes;
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
    files.add(
      _AudioFile(
        path: entity.path,
        modifiedMs: _modifiedMs(entity),
        sizeBytes: _sizeBytes(entity),
      ),
    );
  }
  return files;
}

int? _modifiedMs(File file) {
  try {
    return file.lastModifiedSync().millisecondsSinceEpoch;
  } on FileSystemException {
    return null;
  }
}

int? _sizeBytes(File file) {
  try {
    return file.lengthSync();
  } on FileSystemException {
    return null;
  }
}

bool _isAudioPath(String path) {
  final ext = p.extension(path).toLowerCase();
  if (ext.isEmpty) return false;
  return supportedFileExtensions.contains(ext);
}
