import 'dart:async';

import 'package:drift/drift.dart';
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

  test('skipping and jumping forward discard consumed queue history', () async {
    final ids = await insertTitles(['First', 'Second', 'Third', 'Fourth']);
    await controller().playTracks(ids);

    await controller().skipNext();
    expect(ui().queueIds, ids.sublist(1));
    expect(ui().historyIds, [ids.first]);
    expect(ui().title, 'Second');

    await controller().playQueueIndex(2);
    expect(ui().queueIds, [ids.last]);
    expect(ui().historyIds, ids.sublist(0, 3));
    expect(ui().title, 'Fourth');
    expect(ui().upcomingIds, isEmpty);
  });

  test(
    'queue editing APIs preserve current track and publish changes',
    () async {
      final ids = await insertTitles(['First', 'Second', 'Third', 'Fourth']);
      await controller().playTracks(ids.take(3).toList());

      controller().playNext(ids.last);
      expect(ui().queueIds, [ids[0], ids[3], ids[1], ids[2]]);
      controller().moveUpcoming(3, 1);
      expect(ui().queueIds, [ids[0], ids[2], ids[3], ids[1]]);
      controller().removeUpcomingAt(2);
      expect(ui().queueIds, [ids[0], ids[2], ids[1]]);
      controller().clearUpcoming();
      expect(ui().queueIds, [ids.first]);
      expect(ui().trackId, ids.first);
    },
  );

  test('pause during a slow open remains paused after it finishes', () async {
    final ids = await insertTitles(['First']);
    final gate = Completer<void>();
    engine.playBlock = gate;
    final opening = controller().playTracks(ids);
    await pumpEventQueue();
    expect(ui().title, 'First');
    await controller().togglePlayPause();
    expect(ui().playing, isFalse);
    gate.complete();
    await opening;
    expect(ui().playing, isFalse);
    expect(engine.paused, isTrue);
  });

  test(
    'resume after a slow pause wins at the engine as well as the UI',
    () async {
      final ids = await insertTitles(['First']);
      await controller().playTracks(ids);
      final gate = Completer<void>();
      engine.pauseBlock = gate;
      final pausing = controller().togglePlayPause();
      await pumpEventQueue();
      final resuming = controller().togglePlayPause();
      expect(ui().playing, isTrue);
      gate.complete();
      await Future.wait([pausing, resuming]);
      expect(engine.paused, isFalse);
      expect(ui().playing, isTrue);
    },
  );

  test(
    'play during paused session loading is not overwritten by restore',
    () async {
      final ids = await insertTitles(['First']);
      sessionStore.value = PlaybackSession(queueIds: ids, index: 0);
      final gate = Completer<void>();
      engine.loadBlock = gate;
      controller();
      await pumpEventQueue();
      expect(ui().title, 'First');
      await controller().togglePlayPause();
      gate.complete();
      await pumpEventQueue();
      expect(ui().playing, isTrue);
      expect(engine.paused, isFalse);
    },
  );

  test(
    'selecting a new track during restore does not inherit the old playhead',
    () async {
      final ids = await insertTitles(['First', 'Second']);
      sessionStore.value = PlaybackSession(
        queueIds: ids,
        index: 0,
        position: const Duration(seconds: 42),
      );
      final gate = Completer<void>();
      engine.loadBlock = gate;
      controller();
      await pumpEventQueue();
      await controller().playTracks(ids, startIndex: 1);
      gate.complete();
      await pumpEventQueue();
      expect(ui().title, 'Second');
      expect(ui().playing, isTrue);
      expect(engine.paused, isFalse);
      expect(engine.lastSeek, Duration.zero);
    },
  );

  test(
    'final track completion stops UI and Play reopens from the start',
    () async {
      final ids = await insertTitles(['First']);
      await controller().playTracks(ids);
      engine.emitCompleted();
      await pumpEventQueue();
      expect(ui().playing, isFalse);
      expect(ui().position, ui().duration);
      expect(ui().trackId, ids.single);
      await controller().togglePlayPause();
      expect(engine.playCount, 2);
      expect(ui().playing, isTrue);
      expect(ui().position, Duration.zero);
    },
  );

  test(
    'completion consumes history and repeat modes use the remaining queue',
    () async {
      final ids = await insertTitles(['First', 'Second']);
      await controller().playTracks(ids);
      engine.emitCompleted();
      await pumpEventQueue();
      expect(ui().trackId, ids.last);
      expect(ui().playing, isTrue);
      controller().cycleRepeat(); // all
      engine.emitCompleted();
      await pumpEventQueue();
      expect(ui().trackId, ids.last);
      controller().cycleRepeat(); // one
      engine.emitCompleted();
      await pumpEventQueue();
      expect(ui().trackId, ids.last);
      expect(engine.playCount, 4);
      expect(ui().playing, isTrue);
    },
  );

  test(
    'automatic advance failure stops playback without an unhandled error',
    () async {
      final ids = await insertTitles(['First', 'Second']);
      await controller().playTracks(ids);
      engine.playError = StateError('Unreadable file');
      engine.emitCompleted();
      await pumpEventQueue();
      expect(ui().trackId, ids.last);
      expect(ui().playing, isFalse);
      expect(engine.paused, isTrue);
      engine.playError = null;
      await controller().togglePlayPause();
      expect(ui().playing, isTrue);
      expect(engine.lastUri.toString(), contains('Second.flac'));
    },
  );

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
    expect(engine.playCount, 0);
    expect(engine.loadCount, 1);
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
    expect(sessionStore.value.queueIds, [ids.last]);
    expect(sessionStore.value.index, 0);
    expect(
      sessionStore.value.position,
      const Duration(minutes: 1, seconds: 30),
    );
  });

  test('toggleShuffle reorders upcoming ids and restores them', () async {
    final ids = await insertTitles(['A', 'B', 'C', 'D']);
    await controller().playTracks(ids, startIndex: 1);
    expect(ui().queueIds, ids.sublist(1));
    expect(ui().trackId, ids[1]);

    controller().toggleShuffle();
    expect(ui().shuffle, isTrue);
    expect(ui().queueIds.first, ids[1]);
    expect(ui().queueIds.toSet(), ids.sublist(1).toSet());
    expect(ui().trackId, ids[1]);

    controller().toggleShuffle();
    expect(ui().shuffle, isFalse);
    expect(ui().queueIds, ids.sublist(1));
    expect(ui().trackId, ids[1]);
  });

  test(
    'opening a track keeps tagged duration until the engine reports',
    () async {
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/music/First.flac',
          title: 'First',
          durationMs: const Value(180000),
        ),
      );
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/music/Second.flac',
          title: 'Second',
          durationMs: const Value(240000),
        ),
      );
      final rows = await db.allTracks();
      final byTitle = {for (final track in rows) track.title: track.id};
      final ids = [byTitle['First']!, byTitle['Second']!];
      await controller().playTracks(ids);
      expect(ui().duration, const Duration(minutes: 3));
      engine.playBlock = Completer<void>();
      final skipped = controller().skipNext();
      await Future<void>.delayed(Duration.zero);
      expect(ui().title, 'Second');
      expect(ui().duration, const Duration(minutes: 4));
      engine.playBlock!.complete();
      engine.playBlock = null;
      await skipped;
      expect(ui().duration, const Duration(minutes: 3));
    },
  );

  test('engine duration 0 does not clear a known length', () async {
    final ids = await insertTitles(['First']);
    await controller().playTracks(ids);
    expect(ui().duration, const Duration(minutes: 3));
    engine.emitDuration(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(ui().duration, const Duration(minutes: 3));
    engine.emitPosition(const Duration(seconds: 12));
    await Future<void>.delayed(Duration.zero);
    expect(ui().position, const Duration(seconds: 12));
    expect(ui().progress, greaterThan(0));
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

  test('play failure clears opening state and propagates error', () async {
    final ids = await insertTitles(['Fail']);
    engine.playError = Exception('Engine play failed');

    // Public callers retain the original error after playback is settled.
    await expectLater(
      () => controller().playTracks(ids),
      throwsA(isA<Exception>()),
    );
    expect(ui().playing, isFalse);
    expect(engine.paused, isTrue);

    // But the controller's internal _opening state should be reset by the finally block,
    // so we should be able to attempt to play again.
    engine.playError = null;
    await controller().playTracks(ids);
    expect(ui().playing, isTrue);
    expect(engine.playCount, 1);
  });
}
