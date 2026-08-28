import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player}) : _player = player ?? Player();

  final Player _player;

  @override
  Future<void> play(Uri uri) {
    return _player.open(Media(uri.toString()));
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
