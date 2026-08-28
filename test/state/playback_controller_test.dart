import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/database.dart';
import 'package:studio/playback/playback_session.dart';
import 'package:studio/playback/playback_session_provider.dart';
import 'package:studio/playback/playback_session_store.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

import '../playback/fake_audio_engine.dart';

void main() {
  late StudioDatabase db;
  late FakeAudioEngine engine;
  late MemoryPlaybackSessionStore sessionStore;
  late ProviderContainer container;

  setUp(() {
    db = StudioDatabase.memory();
    engine = FakeAudioEngine();
    sessionStore = MemoryPlaybackSessionStore();
    container = ProviderContainer(
      overrides: [
        studioDatabaseProvider.overrideWithValue(db),
        audioEngineProvider.overrideWithValue(engine),
        playbackSessionStoreProvider.overrideWithValue(sessionStore),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    engine.dispose();
    await db.close();
  });

  PlaybackController controller() =>
      container.read(playbackControllerProvider.notifier);

  PlaybackUiState ui() => container.read(playbackControllerProvider);

  Future<List<int>> insertTitles(List<String> titles) async {
    for (final title in titles) {
      await db.upsertTrack(
        TracksCompanion.insert(locator: '/music/$title.flac', title: title),
      );
    }
    final rows = await db.allTracks();
    final byTitle = {for (final track in rows) track.title: track.id};
    return [for (final title in titles) byTitle[title]!];
  }

  test('pause flips playing before the engine returns', () async {
    final ids = await insertTitles(['First']);
    await controller().playTracks(ids);
    engine.pauseBlock = Completer<void>();
    final paused = controller().togglePlayPause();
    expect(ui().playing, isFalse);
    engine.pauseBlock!.complete();
    engine.pauseBlock = null;
    await paused;
    expect(engine.paused, isTrue);
  });

  test('skip during a slow open still lands on the next track', () async {
    final ids = await insertTitles(['First', 'Second']);
    engine.playBlock = Completer<void>();
    final opened = controller().playTracks(ids);
    await Future<void>.delayed(Duration.zero);
    expect(ui().title, 'First');
    await controller().skipNext();
    engine.playBlock!.complete();
    engine.playBlock = null;
    await opened;
    expect(ui().title, 'Second');
    expect(engine.lastUri.toString(), contains('Second.flac'));
  });

  test('seekFraction ignores stale engine ticks after a jump', () async {
    final ids = await insertTitles(['First']);
    await controller().playTracks(ids);
    await Future<void>.delayed(Duration.zero);
    await controller().seekFraction(0.5);
    expect(ui().position, const Duration(minutes: 1, seconds: 30));
    expect(engine.lastSeek, const Duration(minutes: 1, seconds: 30));

    engine.emitPosition(const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    expect(ui().position, const Duration(minutes: 1, seconds: 30));

    engine.emitPosition(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(ui().position, const Duration(minutes: 1, seconds: 30));

    engine.emitPosition(const Duration(minutes: 1, seconds: 31));
    await Future<void>.delayed(Duration.zero);
    engine.emitPosition(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(ui().position, isNot(Duration.zero));
  });

  test('restores queue and playhead paused', () async {
    final ids = await insertTitles(['First', 'Second', 'Third']);
    sessionStore.value = PlaybackSession(
      queueIds: ids,
      index: 1,
      position: const Duration(seconds: 42),
    );
    controller();
    await pumpEventQueue(times: 50);
    expect(ui().title, 'Second');
    expect(ui().playing, isFalse);
    expect(ui().position, const Duration(seconds: 42));
    expect(engine.paused, isTrue);
    expect(engine.lastSeek, const Duration(seconds: 42));
  });

  test('restore drops tracks that are no longer in the library', () async {
    final ids = await insertTitles(['Keep']);
    sessionStore.value = PlaybackSession(
      queueIds: [ids[0], 999],
      index: 1,
      position: const Duration(seconds: 9),
    );
    controller();
    await pumpEventQueue(times: 50);
    expect(ui().title, 'Keep');
    expect(ui().queueIds, [ids[0]]);
    expect(ui().position, Duration.zero);
  });

  test('saveSession writes queue index and playhead', () async {
    final ids = await insertTitles(['First', 'Second']);
    await controller().playTracks(ids, startIndex: 1);
    await controller().seekFraction(0.5);
    controller().saveSession();
    expect(sessionStore.value.queueIds, ids);
    expect(sessionStore.value.index, 1);
    expect(
      sessionStore.value.position,
      const Duration(minutes: 1, seconds: 30),
    );
  });

  test('toggleShuffle reorders upcoming ids and restores them', () async {
    final ids = await insertTitles(['A', 'B', 'C', 'D']);
    await controller().playTracks(ids, startIndex: 1);
    expect(ui().queueIds, ids);
    expect(ui().trackId, ids[1]);

    controller().toggleShuffle();
    expect(ui().shuffle, isTrue);
    expect(ui().queueIds.first, ids[1]);
    expect(ui().queueIds.toSet(), ids.toSet());
    expect(ui().trackId, ids[1]);

    controller().toggleShuffle();
    expect(ui().shuffle, isFalse);
    expect(ui().queueIds, ids);
    expect(ui().trackId, ids[1]);
  });

  test('skipNext after shuffle keeps playing', () async {
    final ids = await insertTitles(['A', 'B', 'C']);
    await controller().playTracks(ids);
    controller().toggleShuffle();
    await controller().skipNext();
    expect(ui().playing, isTrue);
    expect(engine.paused, isFalse);
    expect(ui().title, isNot('A'));
  });
}
