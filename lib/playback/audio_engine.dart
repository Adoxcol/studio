import 'package:studio/playback/dsp/replay_gain.dart';

/// Audio engine contract. Implementations must accept a playable [Uri] only —
/// never a filesystem path or a "local vs streaming" branch.
abstract interface class AudioEngine {
  Future<void> play(Uri uri);

  /// Decode [uri] and sit paused. Must not emit audible samples.
  Future<void> load(Uri uri);
  Future<void> prepare(Uri uri);
  Future<void> crossfadeTo(Uri uri);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setReplayGain(ReplayGainMode mode);
  Future<void> setEqualizer(List<double> gains);
  Future<void> setCrossfade(Duration duration);

  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<void> get completed;
  Stream<List<double>> get spectrum;

  void dispose();
}
