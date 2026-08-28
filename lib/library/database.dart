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
  int get schemaVersion => 1;

  Stream<List<Track>> watchTracks() {
    return (select(tracks)..orderBy([
          (t) => OrderingTerm(expression: t.album),
          (t) => OrderingTerm(expression: t.trackNumber),
          (t) => OrderingTerm(expression: t.title),
        ]))
        .watch();
  }

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
