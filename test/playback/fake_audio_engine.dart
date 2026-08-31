import 'dart:async';

import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

class FakeAudioEngine implements AudioEngine {
  Uri? lastUri;
  var paused = false;
  Duration lastSeek = Duration.zero;
  double lastVolume = 1;
  ReplayGainMode lastReplayGain = ReplayGainMode.off;
  List<double> lastEqualizer = const [];
  double lastEqualizerPreamp = 0;
  Duration lastCrossfade = Duration.zero;
  Uri? lastPrepared;
  Uri? lastCrossfadeTo;
  var seekCount = 0;
  var playCount = 0;
  var loadCount = 0;
  Completer<void>? playBlock;
  Completer<void>? pauseBlock;
  Object? playError;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _spectrum = StreamController<List<double>>.broadcast();

  @override
  Future<void> play(Uri uri) async {
    final gate = playBlock;
    if (gate != null) await gate.future;
    if (playError != null) throw playError!;
    lastUri = uri;
    playCount++;
    paused = false;
    _playing.add(true);
    _duration.add(const Duration(minutes: 3));
    _position.add(Duration.zero);
  }

  @override
  Future<void> load(Uri uri) async {
    lastUri = uri;
    loadCount++;
    paused = true;
    _playing.add(false);
    _duration.add(const Duration(minutes: 3));
    _position.add(Duration.zero);
  }

  @override
  Future<void> prepare(Uri uri) async {
    lastPrepared = uri;
  }

  @override
  Future<void> crossfadeTo(Uri uri) async {
    lastCrossfadeTo = uri;
    await play(uri);
  }

  @override
  Future<void> pause() async {
    final gate = pauseBlock;
    if (gate != null) await gate.future;
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
    seekCount++;
    lastSeek = position;
    _position.add(position);
  }

  void emitPosition(Duration position) => _position.add(position);

  void emitDuration(Duration duration) => _duration.add(duration);

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setReplayGain(ReplayGainMode mode) async {
    lastReplayGain = mode;
  }

  @override
  Future<void> setEqualizer(List<double> gains, {double preamp = 0}) async {
    lastEqualizer = List<double>.from(gains);
    lastEqualizerPreamp = preamp;
  }

  @override
  Future<void> setCrossfade(Duration duration) async {
    lastCrossfade = duration;
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
  Stream<List<double>> get spectrum => _spectrum.stream;

  @override
  void dispose() {
    unawaited(_position.close());
    unawaited(_duration.close());
    unawaited(_playing.close());
    unawaited(_completed.close());
    unawaited(_spectrum.close());
  }
}
