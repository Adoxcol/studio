import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player}) : _player = player ?? Player();

  final Player _player;
  ReplayGainMode _replayGain = ReplayGainMode.off;

  @override
  Future<void> play(Uri uri) async {
    await _applyReplayGain();
    await _player.open(Media(uri.toString()));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume((volume.clamp(0.0, 1.0) * 100));
  }

  @override
  Future<void> setReplayGain(ReplayGainMode mode) {
    _replayGain = mode;
    return _applyReplayGain();
  }

  Future<void> _applyReplayGain() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('replaygain', _replayGain.mpvValue);
    }
  }

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<void> get completed =>
      _player.stream.completed.where((done) => done).map((_) {});

  @override
  void dispose() {
    _player.dispose();
  }
}
