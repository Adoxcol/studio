import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/scrobbling/data/scrobble_queue_store.dart';
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/domain/scrobble_track.dart';
import 'package:studio/features/scrobbling/domain/scrobble_tracker.dart';
import 'package:studio/features/scrobbling/domain/scrobbler.dart';

class FakeService implements ScrobbleService {
  FakeService({this.id = 'fake', this.maxBatch = 50});

  @override
  final String id;
  @override
  final int maxBatch;

  final submitted = <List<ScrobbleTrack>>[];
  final nowPlayingTracks = <ScrobbleTrack>[];
  ScrobbleFailure? failWith;

  @override
  Future<void> nowPlaying(ScrobbleTrack track) async {
    if (failWith != null) throw ScrobbleException(failWith!, 'fail');
    nowPlayingTracks.add(track);
  }

  @override
  Future<void> submit(List<ScrobbleTrack> batch) async {
    if (failWith != null) throw ScrobbleException(failWith!, 'fail');
    submitted.add(batch);
  }
}

ScrobbleTrack track(int i) => ScrobbleTrack(
  artist: 'A',
  title: 'T$i',
  startedAt: DateTime.utc(2026, 1, 1, 0, i),
  duration: const Duration(minutes: 3),
);

void main() {
  test('sends now playing and submits scrobbles to every service', () async {
    final a = FakeService(id: 'a');
    final b = FakeService(id: 'b');
    final scrobbler = Scrobbler(store: MemoryScrobbleQueueStore())
      ..configure([a, b]);
    await scrobbler.handle(NowPlayingEvent(track(1)));
    await scrobbler.handle(ScrobbleReadyEvent(track(1)));
    expect(a.nowPlayingTracks, [track(1)]);
    expect(b.submitted, [
      [track(1)],
    ]);
    expect(scrobbler.pending('a'), 0);
  });

  test('keeps scrobbles through an outage and retries with backoff', () async {
    final store = MemoryScrobbleQueueStore();
    final service = FakeService()..failWith = ScrobbleFailure.retry;
    final scrobbler = Scrobbler(
      store: store,
      retryAfter: const Duration(milliseconds: 20),
    )..configure([service]);
    addTearDown(scrobbler.dispose);
    await scrobbler.handle(ScrobbleReadyEvent(track(1)));
    await scrobbler.handle(ScrobbleReadyEvent(track(2)));
    expect(scrobbler.pending('fake'), 2);
    expect(store.load()['fake'], [track(1), track(2)]);

    // First retry (20 ms) still fails; the next waits twice as long.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(service.submitted, isEmpty);
    service.failWith = null;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(service.submitted, [
      [track(1), track(2)],
    ]);
    expect(scrobbler.pending('fake'), 0);
    expect(store.load()['fake'], isEmpty);
  });

  test('splits large queues into batches', () async {
    final service = FakeService(maxBatch: 2);
    final store = MemoryScrobbleQueueStore()
      ..value = {
        'fake': [for (var i = 0; i < 5; i++) track(i)],
      };
    final scrobbler = Scrobbler(store: store);
    scrobbler.configure([service]);
    await scrobbler.flush('fake');
    expect(service.submitted.map((b) => b.length), [2, 2, 1]);
  });

  test('rejected auth stops the service but keeps its queue', () async {
    final expired = <String>[];
    final service = FakeService()..failWith = ScrobbleFailure.auth;
    final scrobbler = Scrobbler(
      store: MemoryScrobbleQueueStore(),
      onAuthFailure: expired.add,
    )..configure([service]);
    await scrobbler.handle(ScrobbleReadyEvent(track(1)));
    expect(expired, ['fake']);
    expect(scrobbler.pending('fake'), 1);

    service.failWith = null;
    scrobbler.configure([service]);
    await scrobbler.flush('fake');
    expect(service.submitted, [
      [track(1)],
    ]);
  });

  test('a batch the service refuses is dropped', () async {
    final service = FakeService()..failWith = ScrobbleFailure.rejected;
    final scrobbler = Scrobbler(store: MemoryScrobbleQueueStore())
      ..configure([service]);
    await scrobbler.handle(ScrobbleReadyEvent(track(1)));
    expect(scrobbler.pending('fake'), 0);
  });

  test('caps each queue at maxQueued, dropping the oldest', () async {
    final service = FakeService()..failWith = ScrobbleFailure.auth;
    final scrobbler = Scrobbler(store: MemoryScrobbleQueueStore(), maxQueued: 2)
      ..configure([service]);
    await scrobbler.handle(ScrobbleReadyEvent(track(1)));
    scrobbler.configure([service]);
    await scrobbler.handle(ScrobbleReadyEvent(track(2)));
    scrobbler.configure([service]);
    await scrobbler.handle(ScrobbleReadyEvent(track(3)));
    expect(scrobbler.pending('fake'), 2);
  });

  test('a scrobble arriving mid-submit is sent in the same flush', () async {
    final gate = Completer<void>();
    final service = _GatedService(gate.future);
    final scrobbler = Scrobbler(store: MemoryScrobbleQueueStore())
      ..configure([service]);
    final first = scrobbler.handle(ScrobbleReadyEvent(track(1)));
    await Future<void>.delayed(Duration.zero);
    final second = scrobbler.handle(ScrobbleReadyEvent(track(2)));
    gate.complete();
    await Future.wait([first, second]);
    expect(service.submitted, [
      [track(1)],
      [track(2)],
    ]);
    expect(scrobbler.pending('fake'), 0);
  });
}

class _GatedService extends FakeService {
  _GatedService(this.gate);
  final Future<void> gate;

  @override
  Future<void> submit(List<ScrobbleTrack> batch) async {
    await gate;
    submitted.add(batch);
  }
}
