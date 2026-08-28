import 'dart:async';

import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

class FakeAudioEngine implements AudioEngine {
  Uri? lastUri;
  var paused = false;
  Duration lastSeek = Duration.zero;
  double lastVolume = 1;
  ReplayGainMode lastReplayGain = ReplayGainMode.off;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();

  @override
  Future<void> play(Uri uri) async {
    lastUri = uri;
    paused = false;
    _playing.add(true);
    _duration.add(const Duration(minutes: 3));
    _position.add(Duration.zero);
  }

  @override
  Future<void> pause() async {
    paused = true;
    _playing.add(false);
  }

  @override
  Future<void> resume() async {
    paused = false;
    _playing.add(true);
  }

  @override
  Future<void> stop() async {
    paused = true;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _position.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setReplayGain(ReplayGainMode mode) async {
    lastReplayGain = mode;
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  void dispose() {
    unawaited(_position.close());
    unawaited(_duration.close());
    unawaited(_playing.close());
    unawaited(_completed.close());
  }
}
