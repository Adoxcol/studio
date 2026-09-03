import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studio/library/tables.dart';
import 'package:studio/library/watch_coalesced_query.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LibraryFolders, Tracks, Playlists, PlaylistEntries])
class StudioDatabase extends _$StudioDatabase {
  StudioDatabase(super.e);

  factory StudioDatabase.memory() => StudioDatabase(NativeDatabase.memory());

  factory StudioDatabase.onFile(File file) {
    return StudioDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _migrateToV2(m);
      }
      if (from < 3) {
        await _migrateToV3(m);
      }
      if (from < 4) {
        await _migrateToV4(m);
      }
      if (from < 5) {
        await _migrateToV5(m);
      }
      if (from < 6) {
        await _migrateToV6(m);
      }
      if (from < 7) {
        // Revalidate legacy tag failures and artwork reused by album title or
        // directory alone. Keep all metadata, IDs and playlist links until each
        // file is successfully reread; offline libraries remain untouched.
        await customStatement(
          "UPDATE tracks SET file_modified_ms = NULL WHERE source = 'local'",
        );
      }
      if (from < 8) {
        final columns = await _columnNames('tracks');
        if (!columns.contains('file_size_bytes')) {
          await m.addColumn(tracks, tracks.fileSizeBytes);
        }
        if (!columns.contains('sample_rate_hz')) {
          await m.addColumn(tracks, tracks.sampleRateHz);
        }
        await customStatement(
          "UPDATE tracks SET file_modified_ms = NULL WHERE source = 'local'",
        );
      }
      if (from < 9) {
        final columns = await _columnNames('playlists');
        if (!columns.contains('smart_rules')) {
          await m.addColumn(playlists, playlists.smartRules);
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// SQLite rejects `ALTER TABLE ... ADD COLUMN` when the default is
  /// `CURRENT_TIMESTAMP`, so `indexed_at` is added with a constant 0 and
  /// then backfilled. Column adds are skipped if a previous attempt already
  /// applied them before `user_version` moved to 2.
  Future<void> _migrateToV2(Migrator m) async {
    final columns = await _columnNames('tracks');
    if (!columns.contains('genre')) {
      await m.addColumn(tracks, tracks.genre);
    }
    if (!columns.contains('indexed_at')) {
      await customStatement(
        'ALTER TABLE tracks ADD COLUMN indexed_at INTEGER NOT NULL DEFAULT 0',
      );
    }
    await customStatement(
      "UPDATE tracks SET indexed_at = CAST(strftime('%s', CURRENT_TIMESTAMP) "
      'AS INTEGER) WHERE indexed_at = 0',
    );
  }

  Future<void> _migrateToV3(Migrator m) async {
    final columns = await _columnNames('tracks');
    if (!columns.contains('artwork_path')) {
      await m.addColumn(tracks, tracks.artworkPath);
    }
  }

  Future<void> _migrateToV4(Migrator m) async {
    final columns = await _columnNames('tracks');
    if (!columns.contains('file_modified_ms')) {
      await m.addColumn(tracks, tracks.fileModifiedMs);
    }
  }

  Future<void> _migrateToV5(Migrator m) async {
    await m.createTable(playlists);
    await m.createTable(playlistEntries);
  }

  Future<void> _migrateToV6(Migrator m) async {
    final columns = await _columnNames('tracks');
    if (!columns.contains('year')) {
      await m.addColumn(tracks, tracks.year);
    }
  }

  Future<Set<String>> _columnNames(String table) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return {for (final row in rows) row.read<String>('name')};
  }

  Stream<List<Track>> watchTracks() {
    return watchCoalescedQuery(
      tableUpdates(TableUpdateQuery.onTable(tracks)),
      () =>
          (select(tracks)..orderBy([
                (t) => OrderingTerm(expression: t.album),
                (t) => OrderingTerm(expression: t.trackNumber),
                (t) => OrderingTerm(expression: t.title),
              ]))
              .get(),
    );
  }

  Future<List<Track>> allTracks() => select(tracks).get();

  Future<List<LibraryFolder>> allFolders() => select(libraryFolders).get();

  Stream<List<LibraryFolder>> watchFolders() {
    return (select(
      libraryFolders,
    )..orderBy([(t) => OrderingTerm(expression: t.path)])).watch();
  }

  Future<List<Track>> tracksInFolder(int folderId) {
    return (select(tracks)..where((t) => t.folderId.equals(folderId))).get();
  }

  Future<Track?> trackById(int id) {
    return (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> updateTrackTags({
    required int id,
    required String title,
    required String? artist,
    required String? album,
    required String? genre,
    required int? year,
    required int? trackNumber,
    required int fileModifiedMs,
    String? artworkPath,
    bool updateArtwork = false,
  }) {
    return (update(tracks)..where((t) => t.id.equals(id))).write(
      TracksCompanion(
        title: Value(title),
        artist: Value(artist),
        album: Value(album),
        genre: Value(genre),
        year: Value(year),
        trackNumber: Value(trackNumber),
        fileModifiedMs: Value(fileModifiedMs),
        artworkPath: updateArtwork ? Value(artworkPath) : const Value.absent(),
      ),
    );
  }

  Future<Set<int>> existingTrackIds(Iterable<int> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return {};
    final rows = await (select(tracks)..where((t) => t.id.isIn(wanted))).get();
    return {for (final row in rows) row.id};
  }

  Future<int> upsertFolder(String folderPath) async {
    final existing = await (select(
      libraryFolders,
    )..where((t) => t.path.equals(folderPath))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(
      libraryFolders,
    ).insert(LibraryFoldersCompanion.insert(path: folderPath));
  }

  Future<void> upsertTrack(TracksCompanion row) {
    return into(tracks).insert(
      row,
      onConflict: DoUpdate(
        (old) => TracksCompanion(
          title: row.title,
          artist: row.artist,
          album: row.album,
          durationMs: row.durationMs,
          trackNumber: row.trackNumber,
          genre: row.genre,
          artworkPath: row.artworkPath,
          year: row.year,
          fileModifiedMs: row.fileModifiedMs,
          folderId: row.folderId,
          source: row.source,
        ),
        target: [tracks.locator],
      ),
    );
  }

  /// One transaction so [watchTracks] emits once per batch, not per file.
  Future<void> upsertTracks(List<TracksCompanion> rows) {
    if (rows.isEmpty) return Future.value();
    if (rows.length == 1) return upsertTrack(rows.first);
    return batch((b) {
      for (final row in rows) {
        b.insert(
          tracks,
          row,
          onConflict: DoUpdate(
            (old) => TracksCompanion(
              title: row.title,
              artist: row.artist,
              album: row.album,
              durationMs: row.durationMs,
              trackNumber: row.trackNumber,
              genre: row.genre,
              artworkPath: row.artworkPath,
              year: row.year,
              fileModifiedMs: row.fileModifiedMs,
              folderId: row.folderId,
              source: row.source,
            ),
            target: [tracks.locator],
          ),
        );
      }
    });
  }

  Future<void> setArtworkPaths(Map<int, String> paths) {
    if (paths.isEmpty) return Future.value();
    return batch((b) {
      for (final entry in paths.entries) {
        b.update(
          tracks,
          TracksCompanion(artworkPath: Value(entry.value)),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
  }

  Future<int> deleteTracksNotKept({
    required int folderId,
    required Set<String> keepLocators,
  }) async {
    final rows = await (select(
      tracks,
    )..where((t) => t.folderId.equals(folderId))).get();
    final ids = [
      for (final row in rows)
        if (!keepLocators.contains(row.locator)) row.id,
    ];
    if (ids.isEmpty) return 0;
    return (delete(tracks)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> deleteFolder(int folderId) async {
    await (delete(tracks)..where((t) => t.folderId.equals(folderId))).go();
    await (delete(libraryFolders)..where((t) => t.id.equals(folderId))).go();
  }

  Stream<List<Playlist>> watchPlaylists() {
    return (select(
      playlists,
    )..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  }

  Future<List<Playlist>> allPlaylists() => select(playlists).get();

  Future<int> createPlaylist(String name, {String? smartRules}) {
    if (smartRules != null) SmartPlaylistDefinition.decode(smartRules);
    final trimmed = name.trim();
    return into(playlists).insert(
      PlaylistsCompanion.insert(
        name: trimmed.isEmpty ? 'Untitled playlist' : trimmed,
        smartRules: Value(smartRules),
      ),
    );
  }

  Future<void> deletePlaylist(int id) async {
    await (delete(playlistEntries)..where((e) => e.playlistId.equals(id))).go();
    await (delete(playlists)..where((p) => p.id.equals(id))).go();
  }

  Future<void> updateSmartPlaylist(int id, String name, String rules) async {
    SmartPlaylistDefinition.decode(rules);
    if (name.trim().isEmpty) {
      throw ArgumentError('A playlist name is required.');
    }
    await (update(
      playlists,
    )..where((p) => p.id.equals(id) & p.smartRules.isNotNull())).write(
      PlaylistsCompanion(name: Value(name.trim()), smartRules: Value(rules)),
    );
  }

  Future<void> addTrackToPlaylist({
    required int playlistId,
    required int trackId,
  }) async {
    final playlist = await (select(
      playlists,
    )..where((p) => p.id.equals(playlistId))).getSingle();
    if (playlist.smartRules != null) {
      throw StateError('Smart playlist membership is controlled by its rules.');
    }
    final existing = await (select(
      playlistEntries,
    )..where((e) => e.playlistId.equals(playlistId))).get();
    await into(playlistEntries).insert(
      PlaylistEntriesCompanion.insert(
        playlistId: playlistId,
        trackId: trackId,
        position: existing.length,
      ),
    );
  }

  Stream<List<Track>> watchPlaylistTracks(int playlistId) {
    return watchCoalescedQuery(
      tableUpdates(
        TableUpdateQuery.onAllTables([tracks, playlists, playlistEntries]),
      ),
      () async {
        final playlist = await (select(
          playlists,
        )..where((p) => p.id.equals(playlistId))).getSingleOrNull();
        if (playlist == null) return <Track>[];
        if (playlist.smartRules case final rules?) {
          return SmartPlaylistDefinition.decode(
            rules,
          ).evaluate(await allTracks());
        }
        return _manualPlaylistTracks(playlistId);
      },
    );
  }

  Future<List<Track>> _manualPlaylistTracks(int playlistId) async {
    final query =
        select(playlistEntries).join([
            innerJoin(tracks, tracks.id.equalsExp(playlistEntries.trackId)),
          ])
          ..where(playlistEntries.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistEntries.position)]);
    return [for (final row in await query.get()) row.readTable(tracks)];
  }
}

Future<StudioDatabase> openStudioDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'studio.sqlite'));
  return StudioDatabase.onFile(file);
}
