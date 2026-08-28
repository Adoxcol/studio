import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';

void main() {
  test('watchTracks emits upserted rows', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    final folderId = await db.upsertFolder(r'C:\music');
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: r'C:\music\a.flac',
        title: 'Track A',
        artist: const Value('Artist'),
        source: const Value(TrackLocator.local),
        folderId: Value(folderId),
      ),
    );

    final rows = await db.watchTracks().first;
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Track A');
    expect(rows.single.source, TrackLocator.local);
    expect(rows.single.genre, equals(null));
    expect(rows.single.indexedAt, isA<DateTime>());
  });

  test('upsert keeps indexedAt and updates genre', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'Track A',
        genre: const Value('Jazz'),
      ),
    );
    final first = (await db.watchTracks().first).single;
    expect(first.genre, 'Jazz');

    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'Track A (remaster)',
        genre: const Value('Blues'),
      ),
    );
    final second = (await db.watchTracks().first).single;
    expect(second.title, 'Track A (remaster)');
    expect(second.genre, 'Blues');
    expect(second.indexedAt, first.indexedAt);
  });

  test('upsert stores artworkPath', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'Track A',
        artworkPath: const Value('/tmp/cover.jpg'),
      ),
    );
    expect((await db.allTracks()).single.artworkPath, '/tmp/cover.jpg');
  });

  test('upsertTracks writes a batch in one go', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    await db.upsertTracks([
      TracksCompanion.insert(locator: '/music/a.flac', title: 'A'),
      TracksCompanion.insert(locator: '/music/b.flac', title: 'B'),
    ]);
    final titles = (await db.allTracks()).map((t) => t.title).toSet();
    expect(titles, {'A', 'B'});
  });

  test(
    'upgrades a v1 library past the non-constant indexed_at default',
    () async {
      final sqlite = sqlite3.openInMemory();
      sqlite.execute('''
CREATE TABLE library_folders (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  path TEXT NOT NULL UNIQUE
);
''');
      sqlite.execute('''
CREATE TABLE tracks (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL DEFAULT 'local',
  locator TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  artist TEXT NULL,
  album TEXT NULL,
  duration_ms INTEGER NULL,
  track_number INTEGER NULL,
  folder_id INTEGER NULL REFERENCES library_folders (id)
);
''');
      sqlite.execute('PRAGMA user_version = 1');
      sqlite.execute(
        "INSERT INTO tracks (locator, title) VALUES ('/music/a.flac', 'Old Track')",
      );

      final db = StudioDatabase(NativeDatabase.opened(sqlite));
      addTearDown(db.close);

      final rows = await db.allTracks();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Old Track');
      expect(rows.single.genre, equals(null));
      expect(rows.single.indexedAt, isA<DateTime>());
      expect(rows.single.indexedAt.isAfter(DateTime.utc(2020)), isTrue);
    },
  );

  test('retries v2 after genre was added but indexed_at was not', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute('''
CREATE TABLE tracks (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  source TEXT NOT NULL DEFAULT 'local',
  locator TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  artist TEXT NULL,
  album TEXT NULL,
  duration_ms INTEGER NULL,
  track_number INTEGER NULL,
  genre TEXT NULL,
  folder_id INTEGER NULL
);
''');
    sqlite.execute('PRAGMA user_version = 1');
    sqlite.execute(
      "INSERT INTO tracks (locator, title) VALUES ('/music/b.flac', 'Partial')",
    );

    final db = StudioDatabase(NativeDatabase.opened(sqlite));
    addTearDown(db.close);

    final rows = await db.allTracks();
    expect(rows.single.title, 'Partial');
    expect(rows.single.indexedAt, isA<DateTime>());
  });
}
