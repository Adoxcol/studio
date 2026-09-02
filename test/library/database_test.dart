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

  test('upsert stores year', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'Track A',
        year: const Value(2024),
      ),
    );
    expect((await db.allTracks()).single.year, 2024);
  });

  test('metadata edit updates tags without replacing technical data', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'Before',
        durationMs: const Value(180000),
        sampleRateHz: const Value(96000),
      ),
    );
    final id = (await db.allTracks()).single.id;

    await db.updateTrackTags(
      id: id,
      title: 'After',
      artist: 'Aria',
      album: 'Blue',
      genre: 'Ambient',
      year: 2026,
      trackNumber: 3,
      fileModifiedMs: 1234,
    );

    final track = (await db.allTracks()).single;
    expect(track.title, 'After');
    expect(track.sampleRateHz, 96000);
    expect(track.durationMs, 180000);
    expect(track.fileModifiedMs, 1234);
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

  test('createPlaylist stores tracks in order', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    await db.upsertTrack(
      TracksCompanion.insert(locator: '/music/a.flac', title: 'A'),
    );
    await db.upsertTrack(
      TracksCompanion.insert(locator: '/music/b.flac', title: 'B'),
    );
    final tracks = await db.allTracks();
    final playlistId = await db.createPlaylist('Late night');
    await db.addTrackToPlaylist(playlistId: playlistId, trackId: tracks[1].id);
    await db.addTrackToPlaylist(playlistId: playlistId, trackId: tracks[0].id);

    final lists = await db.allPlaylists();
    expect(lists, hasLength(1));
    expect(lists.single.name, 'Late night');

    final names = (await db.watchPlaylistTracks(playlistId).first)
        .map((t) => t.title)
        .toList();
    expect(names, ['B', 'A']);

    await db.deletePlaylist(playlistId);
    expect(await db.allPlaylists(), isEmpty);
    expect(await db.allTracks(), hasLength(2));
  });

  test('blank playlist name becomes Untitled playlist', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    await db.createPlaylist('   ');
    expect((await db.allPlaylists()).single.name, 'Untitled playlist');
  });
}
