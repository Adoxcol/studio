import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/dsp/spectrum_analyzer.dart';
import 'package:studio/playback/pcm_fifo.dart';

/// Silent second mpv instance that dumps post-DSP PCM into a FIFO for FFT.
class MpvSpectrumTap {
  MpvSpectrumTap() : _player = Player(configuration: _tapConfig) {
    _paramsSub = _player.stream.audioParams.listen((params) {
      final rate = params.sampleRate;
      if (rate != null && rate >= 8000) _analyzer.sampleRate = rate;
      final channels = params.channelCount;
      if (channels != null && channels > 0) _channels = channels;
    });
  }

  static const _tapConfig = PlayerConfiguration(vo: 'null', muted: true);

  final Player _player;
  final _bands = StreamController<List<double>>.broadcast();
  final _analyzer = SpectrumAnalyzer();

  StreamSubscription<AudioParams>? _paramsSub;
  PcmFifo? _fifo;
  Future<void>? _loop;
  var _running = false;
  var _failed = false;
  var _channels = 2;
  ReplayGainMode _replayGain = ReplayGainMode.off;
  List<double> _equalizer = Equalizer.flat;

  Stream<List<double>> get bands => _bands.stream;

  Future<void> play(Uri uri) async {
    if (_failed) return;
    await stop();
    try {
      final fifo = await PcmFifo.create();
      _fifo = fifo;
      await _configure(fifo.writerPath);
      await _applyFilters();
      _running = true;
      _loop = _readLoop();
      await _player.open(Media(uri.toString()));
      await _applyFilters();
    } on Object catch (error, stack) {
      debugPrint('Spectrum tap failed: $error\n$stack');
      _failed = true;
      await stop();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> seek(Duration position) {
    _analyzer.reset();
    return _player.seek(position);
  }

  Future<void> stop() async {
    _running = false;
    try {
      await _player.stop();
    } on Object {
      // Player may already be idle.
    }
    await _fifo?.close();
    _fifo = null;
    _analyzer.reset();
    await _loop;
    _loop = null;
  }

  Future<void> setReplayGain(ReplayGainMode mode) {
    _replayGain = mode;
    return _applyReplayGain();
  }

  Future<void> setEqualizer(List<double> gains) {
    _equalizer = List<double>.from(gains);
    return _applyEqualizer();
  }

  void dispose() {
    unawaited(stop());
    unawaited(_paramsSub?.cancel());
    unawaited(_bands.close());
    _player.dispose();
  }

  Future<void> _configure(String fifoPath) async {
    final platform = _player.platform;
    if (platform is! NativePlayer) {
      throw StateError('Spectrum tap needs NativePlayer');
    }
    await platform.setProperty('vid', 'no');
    await platform.setProperty('audio-display', 'no');
    await platform.setProperty('ao', 'pcm');
    await platform.setProperty('ao-pcm-waveheader', 'no');
    await platform.setProperty('audio-format', 'float');
    await platform.setProperty('audio-channels', 'stereo');
    await platform.setProperty('ao-pcm-file', fifoPath);
  }

  Future<void> _applyFilters() async {
    await _applyReplayGain();
    await _applyEqualizer();
  }

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

  Future<void> _readLoop() async {
    final fifo = _fifo;
    if (fifo == null) return;
    try {
      while (_running) {
        final sw = Stopwatch()..start();
        const tickMs = 16;
        final bytesWanted =
            (_analyzer.sampleRate * _channels * 4 * tickMs) ~/ 1000;
        final bytes = await fifo.read(bytesWanted);
        if (!_running) break;
        if (bytes.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: tickMs));
          continue;
        }
        final frame = _analyzer.addInterleavedFloat32(
          bytes,
          channels: _channels,
        );
        if (frame != null && !_bands.isClosed) {
          _bands.add(frame);
        }
        final left = tickMs - sw.elapsedMilliseconds;
        if (left > 0) {
          await Future<void>.delayed(Duration(milliseconds: left));
        }
      }
    } on Object catch (error, stack) {
      if (_running) {
        debugPrint('Spectrum tap read failed: $error\n$stack');
      }
    }
  }
}
