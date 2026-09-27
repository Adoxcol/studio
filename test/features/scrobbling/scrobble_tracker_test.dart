import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/scrobbling/domain/scrobble_tracker.dart';
import 'package:studio/state/playback_provider.dart';

void main() {
  late DateTime clock;
  late ScrobbleTracker tracker;

  setUp(() {
    clock = DateTime.utc(2026, 9, 27, 12);
    tracker = ScrobbleTracker(now: () => clock);
  });

  PlaybackUiState state({
    int id = 1,
    int seconds = 0,
    bool playing = true,
    int length = 200,
    String? artist = 'Artist',
  }) => PlaybackUiState(
    trackId: id,
    locator: '/music/$id.flac',
    title: 'Song $id',
    artist: artist,
    album: 'Album',
    playing: playing,
    position: Duration(seconds: seconds),
    duration: Duration(seconds: length),
  );

  /// Plays [from]..[to] in one-second ticks and returns every event.
  List<ScrobbleEvent> play(int from, int to, {int id = 1, int length = 200}) {
    final events = <ScrobbleEvent>[];
    for (var s = from; s <= to; s++) {
      clock = clock.add(const Duration(seconds: 1));
      events.addAll(tracker.observe(state(id: id, seconds: s, length: length)));
    }
    return events;
  }

  test('announces now playing once, then scrobbles at half the track', () {
    final early = play(0, 99);
    expect(early.whereType<NowPlayingEvent>(), hasLength(1));
    expect(early.whereType<ScrobbleReadyEvent>(), isEmpty);
    final late = play(100, 101);
    final scrobbles = late.whereType<ScrobbleReadyEvent>().toList();
    expect(scrobbles, hasLength(1));
    expect(scrobbles.single.track.title, 'Song 1');
    expect(scrobbles.single.track.album, 'Album');
    expect(play(102, 199).whereType<ScrobbleReadyEvent>(), isEmpty);
  });

  test('long tracks scrobble after four minutes', () {
    final events = play(0, 240, length: 1200);
    expect(events.whereType<ScrobbleReadyEvent>(), hasLength(1));
    final beforeCap = ScrobbleTracker(now: () => clock);
    var count = 0;
    for (var s = 0; s < 239; s++) {
      count += beforeCap
          .observe(state(id: 2, seconds: s, length: 1200))
          .whereType<ScrobbleReadyEvent>()
          .length;
    }
    expect(count, 0);
  });

  test('tracks of 30 seconds or less never scrobble', () {
    expect(play(0, 30, length: 30).whereType<ScrobbleReadyEvent>(), isEmpty);
  });

  test('seeking forward does not count as listening', () {
    play(0, 10);
    tracker.observe(state(seconds: 150));
    // 10 s before the seek plus 49 s after it: short of the 100 s needed.
    expect(play(151, 199).whereType<ScrobbleReadyEvent>(), isEmpty);
  });

  test('paused time does not count', () {
    play(0, 50);
    for (var i = 0; i < 100; i++) {
      expect(tracker.observe(state(seconds: 50 + i, playing: false)), isEmpty);
    }
    expect(play(150, 160).whereType<ScrobbleReadyEvent>(), isEmpty);
  });

  test('changing track starts a new listen with its own start time', () {
    play(0, 5);
    final events = play(0, 101, id: 2);
    final nowPlaying = events.whereType<NowPlayingEvent>().single;
    final scrobble = events.whereType<ScrobbleReadyEvent>().single;
    expect(nowPlaying.track.title, 'Song 2');
    expect(scrobble.track.startedAt, nowPlaying.track.startedAt);
  });

  test('repeat-one replay earns a second scrobble', () {
    expect(play(0, 199).whereType<ScrobbleReadyEvent>(), hasLength(1));
    final replay = play(0, 101);
    expect(replay.whereType<NowPlayingEvent>(), hasLength(1));
    expect(replay.whereType<ScrobbleReadyEvent>(), hasLength(1));
  });

  test('tracks without an artist are ignored', () {
    for (var s = 0; s < 150; s++) {
      expect(tracker.observe(state(seconds: s, artist: ' ')), isEmpty);
    }
  });
}
