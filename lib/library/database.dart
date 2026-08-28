import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:studio/library/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [LibraryFolders, Tracks])
class StudioDatabase extends _$StudioDatabase {
  StudioDatabase(super.e);

  factory StudioDatabase.memory() => StudioDatabase(NativeDatabase.memory());

  factory StudioDatabase.onFile(File file) {
    return StudioDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _migrateToV2(m);
      }
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

  Future<Set<String>> _columnNames(String table) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return {for (final row in rows) row.read<String>('name')};
  }

  Stream<List<Track>> watchTracks() {
    return (select(tracks)..orderBy([
          (t) => OrderingTerm(expression: t.album),
          (t) => OrderingTerm(expression: t.trackNumber),
          (t) => OrderingTerm(expression: t.title),
        ]))
        .watch();
  }

  Future<List<Track>> allTracks() => select(tracks).get();

  Future<Track?> trackById(int id) {
    return (select(tracks)..where((t) => t.id.equals(id))).getSingleOrNull();
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
          folderId: row.folderId,
          source: row.source,
        ),
        target: [tracks.locator],
      ),
    );
  }
}

Future<StudioDatabase> openStudioDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final file = File(p.join(dir.path, 'studio.sqlite'));
  return StudioDatabase.onFile(file);
}
