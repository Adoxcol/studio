import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
