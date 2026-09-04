import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/library/database.dart';

import '../../helpers/playlists.dart';

void main() {
  test('active playlist stream publishes the complete saved order', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final id = await seedPlaylist(db);
    final stream = StreamIterator(db.watchPlaylistTracks(id));
    addTearDown(stream.cancel);
    await stream.moveNext();
    expect(stream.current.map((t) => t.title), ['A', 'B', 'A', 'C']);
    final items = await db.playlistItems(id);
    await db.reorderPlaylistEntries(
      id,
      items.reversed.map((e) => e.entryId).toList(),
    );
    await stream.moveNext();
    expect(stream.current.map((t) => t.title), ['C', 'A', 'B', 'A']);
  });
  test(
    'rename, duplicate, reorder and delete preserve tracks and independent copies',
    () async {
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final id = await seedPlaylist(db);
      await db.renamePlaylist(id, '  Favorites  ');
      expect((await db.allPlaylists()).single.name, 'Favorites');
      await expectLater(db.renamePlaylist(id, '  '), throwsArgumentError);
      await expectLater(db.renamePlaylist(-1, 'Missing'), throwsStateError);
      final original = await db.playlistItems(id);
      final order = original.reversed.map((e) => e.entryId).toList();
      await db.reorderPlaylistEntries(id, order);
      expect((await db.playlistItems(id)).map((e) => e.entryId), order);
      expect((await db.watchPlaylistTracks(id).first).map((t) => t.title), [
        'C',
        'A',
        'B',
        'A',
      ]);

      final copy = await db.duplicatePlaylist(id, 'Copy');
      final copied = await db.playlistItems(copy);
      expect(copied.map((e) => e.track.title), ['C', 'A', 'B', 'A']);
      expect(copied.any((e) => order.contains(e.entryId)), isFalse);
      await db.deletePlaylist(id);
      expect((await db.allPlaylists()).single.id, copy);
      expect(await db.allTracks(), hasLength(3));
      expect(await db.playlistItems(copy), hasLength(4));
      expect(await db.playlistItems(id), isEmpty);
    },
  );

  test('smart copies preserve rules but cannot be reordered', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final rules = SmartPlaylistDefinition(
      rules: const [SmartRule(SmartField.format, SmartOperator.equals, 'flac')],
    ).encode();
    final id = await db.createPlaylist('Lossless', smartRules: rules);
    final copy = await db.duplicatePlaylist(id, 'Lossless copy');
    await db.renamePlaylist(copy, 'Renamed smart');
    expect(
      (await db.allPlaylists()).firstWhere((p) => p.id == copy).smartRules,
      rules,
    );
    await expectLater(db.reorderPlaylistEntries(copy, []), throwsStateError);
    await db.deletePlaylist(id);
    expect((await db.allPlaylists()).single.id, copy);
  });

  test(
    'stale or invalid reorder is atomic and cannot steal another playlist entry',
    () async {
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final id = await seedPlaylist(db);
      final original = (await db.playlistItems(
        id,
      )).map((e) => e.entryId).toList();
      final copy = await db.duplicatePlaylist(id, 'Copy');
      final other = (await db.playlistItems(copy)).first.entryId;
      for (final invalid in [
        original.take(3).toList(),
        [other, ...original.skip(1)],
        [original.first, ...original.take(3)],
      ]) {
        await expectLater(
          db.reorderPlaylistEntries(id, invalid),
          throwsStateError,
        );
        expect((await db.playlistItems(id)).map((e) => e.entryId), original);
      }
      await db.addTrackToPlaylist(
        playlistId: id,
        trackId: (await db.allTracks()).first.id,
      );
      await expectLater(
        db.reorderPlaylistEntries(id, original),
        throwsStateError,
      );
      expect(await db.playlistItems(id), hasLength(5));
    },
  );

  test(
    'adding after a removed entry appends without a tied position',
    () async {
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final id = await seedPlaylist(db);
      final entries = await db.playlistItems(id);
      await (db.delete(
        db.playlistEntries,
      )..where((e) => e.id.equals(entries[1].entryId))).go();
      await db.addTrackToPlaylist(playlistId: id, trackId: entries[1].track.id);
      expect((await db.playlistItems(id)).map((e) => e.track.title), [
        'A',
        'A',
        'C',
        'B',
      ]);
      final positions = (await db.select(db.playlistEntries).get())
          .map((e) => e.position)
          .toSet();
      expect(positions, hasLength(4));
    },
  );

  test('saved order survives restart', () async {
    final root = await Directory.systemTemp.createTemp(
      'studio-playlist-order-',
    );
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/library.sqlite');
    var db = StudioDatabase.onFile(file);
    final id = await seedPlaylist(db);
    final order = (await db.playlistItems(
      id,
    )).reversed.map((e) => e.entryId).toList();
    await db.reorderPlaylistEntries(id, order);
    await db.close();
    db = StudioDatabase.onFile(file);
    addTearDown(db.close);
    expect((await db.playlistItems(id)).map((e) => e.entryId), order);
  });
}
