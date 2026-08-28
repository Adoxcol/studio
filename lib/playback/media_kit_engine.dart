import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/spectrum_tap.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player, MpvSpectrumTap? spectrumTap})
    : _player = player ?? Player(),
      _tap = spectrumTap ?? MpvSpectrumTap();

  final Player _player;
  final MpvSpectrumTap _tap;
  ReplayGainMode _replayGain = ReplayGainMode.off;
  List<double> _equalizer = Equalizer.flat;

  @override
  Future<void> play(Uri uri) async {
    await _applyReplayGain();
    await _applyEqualizer();
    await _player.open(Media(uri.toString()));
    unawaited(_tap.play(uri));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _tap.pause();
  }

  @override
  Future<void> resume() async {
    await _player.play();
    await _tap.resume();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _tap.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    await _tap.seek(position);
  }

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume((volume.clamp(0.0, 1.0) * 100));
  }

  @override
  Future<void> setReplayGain(ReplayGainMode mode) {
    _replayGain = mode;
    return Future.wait([_applyReplayGain(), _tap.setReplayGain(mode)]);
  }

  @override
  Future<void> setEqualizer(List<double> gains) {
    _equalizer = List<double>.from(gains);
    return Future.wait([_applyEqualizer(), _tap.setEqualizer(gains)]);
  }

  @override
  Stream<List<double>> get spectrum => _tap.bands;

  Future<void> _applyReplayGain() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('replaygain', _replayGain.mpvValue);
    }
  }

  Future<void> _applyEqualizer() async {
    final platform = _player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('af', Equalizer.afFilter(_equalizer));
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
    _tap.dispose();
    _player.dispose();
  }
}
