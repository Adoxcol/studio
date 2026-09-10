import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/library/database.dart';

void main() {
  final ambient = SmartPlaylistDefinition(
    rules: const [SmartRule(SmartField.genre, SmartOperator.equals, 'Ambient')],
  );

  test(
    'membership reacts to imports, rule edits, retagging and deletion',
    () async {
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final id = await db.createPlaylist(
        'Ambient',
        smartRules: ambient.encode(),
      );
      final iterator = StreamIterator(db.watchPlaylistTracks(id));
      addTearDown(iterator.cancel);
      await iterator.moveNext();
      expect(iterator.current, isEmpty);
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/a.flac',
          title: 'A',
          genre: const Value('Ambient'),
        ),
      );
      await iterator.moveNext();
      expect(iterator.current.single.title, 'A');
      final track = iterator.current.single;
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/a.flac',
          title: 'A',
          genre: const Value('Jazz'),
        ),
      );
      await iterator.moveNext();
      expect(iterator.current, isEmpty);
      final jazz = SmartPlaylistDefinition(
        rules: const [
          SmartRule(SmartField.genre, SmartOperator.equals, 'Jazz'),
        ],
      );
      await db.updateSmartPlaylist(id, 'Jazz', jazz.encode());
      await iterator.moveNext();
      expect(iterator.current.single.id, track.id);
      await expectLater(
        db.addTrackToPlaylist(playlistId: id, trackId: track.id),
        throwsStateError,
      );
      await (db.delete(db.tracks)..where((t) => t.id.equals(track.id))).go();
      await iterator.moveNext();
      expect(iterator.current, isEmpty);
    },
  );

  test(
    'v8 migration preserves ordinary playlists and smart rules survive restart',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'studio-smart-migration-',
      );
      addTearDown(() => root.delete(recursive: true));
      final file = File('${root.path}/library.sqlite');
      var db = StudioDatabase(NativeDatabase(file));
      await db.upsertTrack(
        TracksCompanion.insert(locator: '/keep.flac', title: 'Keep'),
      );
      final track = (await db.allTracks()).single;
      final manual = await db.createPlaylist('Manual');
      await db.addTrackToPlaylist(playlistId: manual, trackId: track.id);
      await db.customStatement('ALTER TABLE playlists DROP COLUMN smart_rules');
      await db.customStatement('PRAGMA user_version = 8');
      await db.close();
      db = StudioDatabase(NativeDatabase(file));
      expect((await db.watchPlaylistTracks(manual).first).single.title, 'Keep');
      expect((await db.allPlaylists()).single.smartRules, isNull);
      final smart = await db.createPlaylist(
        'Ambient',
        smartRules: ambient.encode(),
      );
      await db.close();
      db = StudioDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        (await db.allPlaylists()).firstWhere((p) => p.id == smart).smartRules,
        ambient.encode(),
      );
    },
  );
}
