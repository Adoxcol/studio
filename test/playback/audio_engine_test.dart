import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

// Create a generic test suite for any AudioEngine implementation
void testAudioEngineContract(AudioEngine Function() createEngine) {
  group('AudioEngine Contract', () {
    late AudioEngine engine;

    setUp(() {
      engine = createEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test('initial state streams correctly', () async {
      final playingFuture = engine.playing.first;
      engine.pause(); // trigger stream if needed based on implementation,
      // but typical engines might not emit immediately unless triggered.
      expect(await playingFuture, isFalse);

      // We assume an engine should not crash when calling these before play
      await engine.setVolume(1.0);
      await engine.setReplayGain(ReplayGainMode.off);
    });

    test('stop() without play does not crash', () async {
      await engine.stop();
    });

    test('pause() and resume() without play does not crash', () async {
      await engine.pause();
      await engine.resume();
    });
  });
}

void main() {
  // Test our fake implementation against the contract,
  // ensuring the interface testing is possible.
  testAudioEngineContract(() => _TestFakeAudioEngine());
}

// A simple fake to verify our contract test works against an implementation.
class _TestFakeAudioEngine implements AudioEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _spectrum = StreamController<List<double>>.broadcast();

  @override
  Future<void> play(Uri uri) async {
    _playing.add(true);
  }

  @override
  Future<void> load(Uri uri) async {
    _playing.add(false);
  }

  @override
  Future<void> prepare(Uri uri) async {}

  @override
  Future<void> crossfadeTo(Uri uri) async {}

  @override
  Future<void> pause() async {
    _playing.add(false);
  }

  @override
  Future<void> resume() async {
    _playing.add(true);
  }

  @override
  Future<void> stop() async {
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setReplayGain(ReplayGainMode mode) async {}

  @override
  Future<void> setEqualizer(List<double> gains, {double preamp = 0}) async {}

  @override
  Future<void> setCrossfade(Duration duration) async {}

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<List<double>> get spectrum => _spectrum.stream;

  @override
  void dispose() {
    _position.close();
    _duration.close();
    _playing.close();
    _completed.close();
    _spectrum.close();
  }
}
