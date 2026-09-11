import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/database.dart';

void main() {
  late StudioDatabase db;

  setUp(() {
    db = StudioDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  test('watchTracks only returns tracks with matching source', () async {
    // Insert local track
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            locator: '/music/song1.mp3',
            title: 'Local Song',
            artist: const Value('Local Artist'),
            album: const Value('Local Album'),
            source: const Value('local'),
          ),
        );

    // Insert subsonic track
    await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            locator: 'subsonic://song-999',
            title: 'Remote Song',
            artist: const Value('Remote Artist'),
            album: const Value('Remote Album'),
            source: const Value('subsonic'),
          ),
        );

    final localTracks = await db.watchTracks().first;
    expect(localTracks.length, 1);
    expect(localTracks.first.title, 'Local Song');
    expect(localTracks.first.source, 'local');

    final subsonicTracks = await db.watchTracks(source: 'subsonic').first;
    expect(subsonicTracks.length, 1);
    expect(subsonicTracks.first.title, 'Remote Song');
    expect(subsonicTracks.first.source, 'subsonic');
  });

  test(
    'getOrInsertTrack reuses existing track or inserts new record',
    () async {
      final companion = TracksCompanion.insert(
        locator: 'subsonic://stream-1',
        title: 'Stream Track',
        artist: const Value('Stream Artist'),
        album: const Value('Stream Album'),
        source: const Value('subsonic'),
      );

      final track1 = await db.getOrInsertTrack(companion);
      expect(track1.id, isPositive);
      expect(track1.title, 'Stream Track');

      final track2 = await db.getOrInsertTrack(companion);
      expect(track2.id, track1.id);
    },
  );
}
