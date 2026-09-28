import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio/features/listening_stats/domain/listening_stats.dart';
import 'package:studio/features/listening_stats/presentation/listening_stats_providers.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

PlayEvent play(
  DateTime at, {
  String title = 'Song',
  String? artist = 'Artist',
  String? album = 'Album',
  int? trackId,
  int durationMs = 180000,
}) => PlayEvent(
  id: 0,
  trackId: trackId,
  title: title,
  artist: artist,
  album: album,
  durationMs: durationMs,
  playedAt: at,
);

void main() {
  group('ListeningStats.from', () {
    test('an empty history has no stats', () {
      final stats = ListeningStats.from(const []);
      expect(stats.plays, 0);
      expect(stats.longestStreak, 0);
      expect(stats.busiestDay, isNull);
      expect(stats.playsByMonth, List.filled(12, 0));
    });

    test('totals, credits, albums and tracks', () {
      final stats = ListeningStats.from([
        play(
          DateTime(2026, 3, 1, 10),
          title: 'Jóga',
          artist: 'Björk',
          trackId: 1,
        ),
        play(
          DateTime(2026, 3, 1, 11),
          title: 'Jóga',
          artist: 'Björk',
          trackId: 1,
        ),
        play(
          DateTime(2026, 3, 2, 9),
          title: 'Collab',
          artist: 'Björk feat. Arca',
          album: 'Utopia',
        ),
        play(DateTime(2026, 4, 9), title: 'Loose', artist: null, album: null),
      ]);
      expect(stats.plays, 4);
      expect(stats.listening, const Duration(minutes: 12));
      expect(stats.artists, 2);
      expect(stats.days, 3);
      expect(stats.topArtists.map((a) => (a.label, a.plays)), [
        ('Björk', 3),
        ('Arca', 1),
      ]);
      expect(stats.topAlbums.first.label, 'Album');
      expect(stats.topAlbums.first.detail, 'Björk');
      expect(stats.topAlbums.first.plays, 2);
      expect(stats.topTracks.first.label, 'Jóga');
      expect(stats.topTracks.first.plays, 2);
      expect(stats.topTracks, hasLength(3));
      expect(stats.playsByMonth[2], 3);
      expect(stats.playsByMonth[3], 1);
    });

    test('tracks without an id are grouped by title and artist', () {
      final stats = ListeningStats.from([
        play(DateTime(2026, 1, 1), title: 'Same', artist: 'A'),
        play(DateTime(2026, 1, 2), title: 'same', artist: 'a'),
        play(DateTime(2026, 1, 3), title: 'Same', artist: 'B'),
      ]);
      expect(stats.topTracks.map((t) => t.plays), [2, 1]);
    });

    test('streak and busiest day use local calendar days', () {
      final stats = ListeningStats.from([
        play(DateTime(2026, 5, 1, 23)),
        play(DateTime(2026, 5, 2, 8)),
        play(DateTime(2026, 5, 3, 8)),
        play(DateTime(2026, 5, 3, 9)),
        play(DateTime(2026, 5, 3, 10)),
        play(DateTime(2026, 5, 10)),
        play(DateTime(2026, 5, 11)),
      ]);
      expect(stats.longestStreak, 3);
      expect(stats.busiestDay, DateTime(2026, 5, 3));
      expect(stats.busiestDayPlays, 3);
    });

    test('hours, weekdays, genres, counts and artwork', () {
      // 2026-03-02 is a Monday.
      final stats = ListeningStats.from(
        [
          play(DateTime(2026, 3, 2, 8), title: 'A', trackId: 1),
          play(DateTime(2026, 3, 2, 8, 30), title: 'A', trackId: 1),
          play(DateTime(2026, 3, 8, 22), title: 'B', trackId: 2),
          play(DateTime(2026, 3, 8, 23), title: 'C', album: 'Other'),
        ],
        genreOf: (e) => switch (e.trackId) {
          1 => 'Jazz',
          2 => ' jazz ',
          _ => null,
        },
      );
      expect(stats.playsByHour[8], 2);
      expect(stats.playsByHour[22], 1);
      expect(stats.playsByWeekday.first, 2); // Monday
      expect(stats.playsByWeekday.last, 2); // Sunday
      expect(stats.topGenres.single.label, 'Jazz');
      expect(stats.topGenres.single.plays, 3);
      expect(stats.albums, 2);
      expect(stats.tracks, 3);
      expect(stats.topTracks.first.trackId, 1);
      expect(stats.topAlbums.first.trackId, 1);
      expect(stats.perDay, const Duration(minutes: 6));
      expect(stats.newArtists, isEmpty);
    });

    test('new artists are those not heard before', () {
      final earlier = [play(DateTime(2026, 1, 1), artist: 'Old Friend')];
      final stats = ListeningStats.from([
        play(DateTime(2026, 3, 1), artist: 'Old Friend'),
        play(DateTime(2026, 3, 2), artist: 'Fresh Face'),
        play(DateTime(2026, 3, 3), artist: 'Fresh Face'),
      ], knownArtists: ListeningStats.artistsIn(earlier));
      expect(stats.newArtists.map((a) => a.label), ['Fresh Face']);
      expect(stats.newArtists.single.plays, 2);
    });

    test('limits rankings to the requested size', () {
      final stats = ListeningStats.from([
        for (var i = 0; i < 20; i++)
          play(DateTime(2026, 1, 1), title: 'T$i', artist: 'A$i'),
      ], top: 5);
      expect(stats.topArtists, hasLength(5));
      expect(stats.topTracks, hasLength(5));
    });
  });

  test('periods start at local midnight', () {
    final now = DateTime(2026, 9, 27, 15, 30);
    expect(StatsPeriod.week.startFrom(now), DateTime(2026, 9, 21));
    expect(StatsPeriod.month.startFrom(now), DateTime(2026, 8, 29));
    expect(StatsPeriod.year.startFrom(now), DateTime(2026));
    expect(StatsPeriod.all.startFrom(now), isNull);
  });

  group('play history in the database', () {
    late StudioDatabase db;
    setUp(() => db = StudioDatabase.memory());
    tearDown(() => db.close());

    test('records, filters by range and clears', () async {
      for (final day in [1, 5, 9]) {
        await db.recordPlay(
          title: 'Day $day',
          artist: 'A',
          playedAt: DateTime.utc(2026, 1, day),
        );
      }
      final range = await db.playEventsBetween(
        from: DateTime.utc(2026, 1, 5),
        to: DateTime.utc(2026, 1, 9),
      );
      expect(range.map((e) => e.title), ['Day 5']);
      expect(await db.playEventsBetween(), hasLength(3));
      expect(await db.watchPlayCount().first, 3);
      await db.clearPlayHistory();
      expect(await db.playEventsBetween(), isEmpty);
    });

    test('history survives deleting the track', () async {
      await db.upsertTrack(
        TracksCompanion.insert(locator: '/a.flac', title: 'Gone'),
      );
      final track = (await db.allTracks()).single;
      await db.recordPlay(
        trackId: track.id,
        title: 'Gone',
        playedAt: DateTime.utc(2026),
      );
      await (db.delete(db.tracks)..where((t) => t.id.equals(track.id))).go();
      final events = await db.playEventsBetween();
      expect(events.single.title, 'Gone');
      expect(events.single.trackId, isNull);
    });
  });

  test('upgrading a v9 library adds play history', () async {
    final sqlite = sqlite3.openInMemory();
    final first = StudioDatabase(
      NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
    );
    await first.allTracks();
    await first.close();
    sqlite.execute('DROP INDEX play_events_played_at');
    sqlite.execute('DROP TABLE play_events');
    sqlite.execute('PRAGMA user_version = 9');

    final db = StudioDatabase(NativeDatabase.opened(sqlite));
    addTearDown(db.close);
    await db.recordPlay(title: 'After upgrade', playedAt: DateTime.utc(2026));
    expect((await db.playEventsBetween()).single.title, 'After upgrade');
    final indexes = sqlite.select(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'play_events_played_at'",
    );
    expect(indexes, hasLength(1));
  });

  test('records a play once the listen passes the threshold', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/a.flac',
        title: 'Counted',
        artist: const Value('Artist'),
      ),
    );
    final track = (await db.allTracks()).single;
    final container = ProviderContainer(
      overrides: [studioDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    container.read(playHistoryRecorderProvider);
    final controller = container.read(playbackControllerProvider.notifier);
    for (var s = 0; s <= 70; s++) {
      controller.state = PlaybackUiState(
        trackId: track.id,
        locator: track.locator,
        title: 'Counted',
        artist: 'Artist',
        playing: true,
        position: Duration(seconds: s),
        duration: const Duration(seconds: 120),
      );
      if (s == 55) expect(await db.playEventsBetween(), isEmpty);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final events = await db.playEventsBetween();
    expect(events.single.trackId, track.id);
    expect(events.single.durationMs, 120000);
  });
}
