import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scanner.dart';
import 'package:studio/library/tag_reader.dart';

class _Reader extends TagReader {
  final tags = <String, ParsedTags>{};
  final failing = <String>{};
  int reads = 0;
  @override
  ParsedTags read(File file, {bool getImage = false}) {
    reads++;
    final name = p.basenameWithoutExtension(file.path);
    if (failing.contains(name)) {
      return ParsedTags(title: name, readSucceeded: false);
    }
    return tags[name] ?? ParsedTags(title: name);
  }
}

// v6 and v7 have the same columns. v7 invalidates old scan stamps once.
class _V6Database extends StudioDatabase {
  _V6Database(super.e);
  @override
  int get schemaVersion => 6;
}

ParsedTags _tags(String artist, String album, {int? image}) => ParsedTags(
  title: '$artist song',
  artist: artist,
  album: album,
  year: 2020,
  duration: const Duration(minutes: 3),
  genre: 'Jazz',
  trackNumber: 2,
  artwork: image == null ? null : Uint8List.fromList([0xff, 0xd8, 0xff, image]),
  artworkMime: 'image/jpeg',
);

void main() {
  late Directory root;
  late StudioDatabase db;
  late _Reader reader;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('studio-scan-recovery-');
    db = StudioDatabase.memory();
    reader = _Reader();
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  FolderScanner scanner() => FolderScanner(
    db: db,
    tagReader: reader,
    artwork: ArtworkStore(Directory(p.join(root.path, 'art'))),
  );
  Future<File> audio(String relative) async {
    final file = File(p.normalize(p.join(root.path, relative)));
    await file.parent.create(recursive: true);
    return file.writeAsString('fixture');
  }

  for (final obstructed in [false, true]) {
    test(
      'unavailable root preserves playlist membership and other roots scan (obstructed: $obstructed)',
      () async {
        final offline = p.join(root.path, 'offline');
        if (obstructed) await File(offline).writeAsString('not a directory');
        final folder = await db.upsertFolder(offline);
        await db.upsertTrack(
          TracksCompanion.insert(
            locator: p.join(offline, 'A.flac'),
            title: 'Saved',
            folderId: Value(folder),
          ),
        );
        final track = (await db.allTracks()).single;
        final playlist = await db.createPlaylist('Keep');
        await db.addTrackToPlaylist(playlistId: playlist, trackId: track.id);
        final online = await audio('online/B.flac');
        await db.upsertFolder(online.parent.path);

        final result = await scanner().rescanKnown();
        expect(result.unavailableFolders, 1);
        expect(await db.allTracks(), hasLength(2));
        expect(
          (await db.watchPlaylistTracks(playlist).first).single.id,
          track.id,
        );
        expect((await db.trackById(track.id))!.title, 'Saved');

        if (!obstructed) {
          await audio('offline/A.flac');
          reader.tags['A'] = _tags('Returned', 'Album');
          await scanner().rescanKnown();
          final restored =
              (await db.watchPlaylistTracks(playlist).first).single;
          expect(restored.id, track.id);
          expect(restored.artist, 'Returned');
        }
      },
    );
  }

  test(
    'successfully enumerated empty directory still prunes deleted files',
    () async {
      final file = await audio('music/A.flac');
      await scanner().scan(file.parent.path);
      await file.delete();
      final result = await scanner().scan(file.parent.path);
      expect(result.unavailableFolders, 0);
      expect(await db.allTracks(), isEmpty);
    },
  );

  for (final sharedDirectory in [false, true]) {
    test(
      'same-named albums retain each artists embedded cover (shared directory: $sharedDirectory)',
      () async {
        for (final name in ['A', 'B']) {
          await audio(
            sharedDirectory ? 'music/$name.flac' : 'music/$name/$name.flac',
          );
          reader.tags[name] = _tags(
            'Artist $name',
            'Greatest Hits',
            image: name.codeUnitAt(0),
          );
        }
        await scanner().scan(p.join(root.path, 'music'));
        final tracks = await db.allTracks();
        expect(tracks.map((t) => t.artworkPath).toSet(), hasLength(2));
        for (final track in tracks) {
          expect(
            (await File(track.artworkPath!).readAsBytes()).last,
            track.artist!.codeUnitAt(track.artist!.length - 1),
          );
        }
      },
    );
  }

  test(
    'sharing a directory does not give a different album someone elses cover',
    () async {
      await audio('music/A.flac');
      await audio('music/B.flac');
      reader.tags['A'] = _tags('Artist', 'One', image: 1);
      reader.tags['B'] = _tags('Artist', 'Two');
      await scanner().scan(p.join(root.path, 'music'));
      final tracks = {for (final t in await db.allTracks()) t.album: t};
      expect(tracks['One']!.artworkPath, isA<String>());
      expect(tracks['Two']!.artworkPath, equals(null));
    },
  );

  test(
    'own embedded artwork takes precedence even within the same album',
    () async {
      for (final name in ['A', 'B']) {
        await audio('music/$name.flac');
        reader.tags[name] = _tags('Artist', 'Album', image: name.codeUnitAt(0));
      }
      await scanner().scan(p.join(root.path, 'music'));
      expect(
        (await db.allTracks()).map((t) => t.artworkPath).toSet(),
        hasLength(2),
      );
    },
  );

  test(
    'failed read preserves all good tags and retries unchanged file in a fresh scanner',
    () async {
      final file = await audio('music/A.flac');
      reader.tags['A'] = _tags('Artist', 'Album', image: 1);
      await scanner().scan(file.parent.path);
      final before = (await db.allTracks()).single;
      await file.setLastModified(DateTime.utc(2020));
      reader.failing.add('A');
      await scanner().scan(file.parent.path);
      final failed = (await db.allTracks()).single;
      expect(failed.id, before.id);
      expect(failed.title, before.title);
      expect(failed.artist, before.artist);
      expect(failed.album, before.album);
      expect(failed.year, before.year);
      expect(failed.durationMs, before.durationMs);
      expect(failed.genre, before.genre);
      expect(failed.trackNumber, before.trackNumber);
      expect(failed.artworkPath, before.artworkPath);
      expect(failed.fileModifiedMs, equals(null));
      reader.failing.clear();
      reader.tags['A'] = _tags('Recovered', 'New album', image: 2);
      await scanner().scan(file.parent.path);
      final recovered = (await db.allTracks()).single;
      expect(recovered.artist, 'Recovered');
      expect(
        recovered.fileModifiedMs,
        (await file.lastModified()).millisecondsSinceEpoch,
      );
      expect(recovered.id, before.id);
      expect(reader.reads, 3);
      expect((await scanner().scan(file.parent.path)).skipped, 1);
    },
  );

  test('first failed read indexes fallback but remains retryable', () async {
    final file = await audio('music/A.flac');
    reader.failing.add('A');
    await scanner().scan(file.parent.path);
    final before = (await db.allTracks()).single;
    expect(before.title, 'A');
    expect(before.fileModifiedMs, equals(null));
    reader.failing.clear();
    reader.tags['A'] = _tags('Recovered', 'Album');
    await scanner().scan(file.parent.path);
    final after = (await db.allTracks()).single;
    expect(after.id, before.id);
    expect(after.artist, 'Recovered');
  });

  test(
    'v6 repair rechecks old artwork without losing IDs or playlists and only runs once',
    () async {
      await db.close();
      final databaseFile = File(p.join(root.path, 'library.sqlite'));
      db = _V6Database(NativeDatabase(databaseFile));
      final music = p.join(root.path, 'music');
      final folder = await db.upsertFolder(music);
      for (final name in ['A', 'B']) {
        final file = await audio('music/$name.flac');
        reader.tags[name] = _tags(
          'Artist $name',
          'Greatest Hits',
          image: name.codeUnitAt(0),
        );
        await db.upsertTrack(
          TracksCompanion.insert(
            locator: file.path,
            title: name,
            artist: Value('Artist $name'),
            album: const Value('Greatest Hits'),
            artworkPath: const Value('old-wrong-cover.jpg'),
            folderId: Value(folder),
            year: const Value(2020),
            fileModifiedMs: Value(
              (await file.lastModified()).millisecondsSinceEpoch,
            ),
          ),
        );
      }
      final before = await db.allTracks();
      final playlist = await db.createPlaylist('Keep');
      await db.addTrackToPlaylist(
        playlistId: playlist,
        trackId: before.first.id,
      );
      await db.close();
      db = StudioDatabase(NativeDatabase(databaseFile));
      final migrated = await db.allTracks();
      expect(migrated.every((t) => t.fileModifiedMs == null), isTrue);
      expect(
        migrated.every((t) => t.artworkPath == 'old-wrong-cover.jpg'),
        isTrue,
      );
      await scanner().rescanKnown();
      expect(
        (await db.allTracks()).map((t) => t.artworkPath).toSet(),
        hasLength(2),
      );
      expect(
        (await db.watchPlaylistTracks(playlist).first).single.id,
        before.first.id,
      );
      await db.close();
      db = StudioDatabase(NativeDatabase(databaseFile));
      expect((await scanner().rescanKnown()).skipped, 2);
      expect(reader.reads, 2);
    },
  );
}
