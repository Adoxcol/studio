import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/dsp/spectrum_analyzer.dart';
import 'package:studio/playback/pcm_fifo.dart';

/// Silent mpv instance that dumps post-DSP PCM into a FIFO for FFT.
///
/// Created lazily. Pipe reads are non-blocking so a stuck tap cannot freeze
/// the Windows UI isolate.
///
/// After [play] opens the file, never call synchronous `setProperty` (or
/// blocking `pause`/`stop`) on this instance. libmpv's `ao=pcm` writer blocks
/// in `fwrite` when the pipe is full; a sync property set from Dart then
/// deadlocks the UI isolate (Windows Not Responding). ReplayGain and EQ are
/// remembered and applied only before the next `open()`.
class MpvSpectrumTap {
  static const _tapConfig = PlayerConfiguration(vo: 'null', muted: true);

  Player? _player;
  final _bands = StreamController<List<double>>.broadcast();
  final _analyzer = SpectrumAnalyzer();

  StreamSubscription<AudioParams>? _paramsSub;
  PcmFifo? _fifo;
  Future<void>? _loop;
  var _running = false;
  var _hold = false;
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
      final player = _ensurePlayer();
      await _configure(player, fifo.writerPath);
      await _applyFilters(player);
      _running = true;
      _hold = false;
      _loop = _readLoop();
      await player.open(Media(uri.toString()));
    } on Object catch (error, stack) {
      debugPrint('Spectrum tap failed: $error\n$stack');
      _failed = true;
      await stop();
    }
  }

  /// Stops emitting bands but keeps draining the pipe. Never talks to libmpv
  /// here — `pause`/`setProperty` on a live `ao=pcm` instance deadlocks the
  /// UI isolate if the writer is blocked in `fwrite`.
  Future<void> pause() async {
    _hold = true;
  }

  Future<void> resume() async {
    _hold = false;
  }

  Future<void> seek(Duration position) async {
    _analyzer.reset();
    final platform = _player?.platform;
    if (platform is NativePlayer) {
      unawaited(platform.seek(position, synchronized: false));
    }
  }

  Future<void> stop() async {
    _running = false;
    _hold = false;
    final fifo = _fifo;
    _fifo = null;
    await fifo?.close();
    // Let the ao thread fail the write before we touch libmpv again.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    try {
      await _loop?.timeout(const Duration(milliseconds: 200));
    } on Object {
      // Reader may already be gone.
    }
    _loop = null;
    _analyzer.reset();
    final player = _player;
    _player = null;
    final paramsSub = _paramsSub;
    _paramsSub = null;
    unawaited(paramsSub?.cancel());
    if (player != null) unawaited(_tearDownPlayer(player));
  }

  void rememberReplayGain(ReplayGainMode mode) {
    _replayGain = mode;
  }

  void rememberEqualizer(List<double> gains) {
    _equalizer = List<double>.from(gains);
  }

  void dispose() {
    unawaited(stop());
    unawaited(_bands.close());
  }

  Future<void> _tearDownPlayer(Player player) async {
    try {
      await player.stop().timeout(const Duration(milliseconds: 300));
    } on Object {
      // Pipe already closed; mpv may error on the way out.
    }
    try {
      player.dispose();
    } on Object {
      // Best-effort.
    }
  }

  Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = Player(configuration: _tapConfig);
    _player = player;
    _paramsSub = player.stream.audioParams.listen((params) {
      final rate = params.sampleRate;
      if (rate != null && rate >= 8000) _analyzer.sampleRate = rate;
      final channels = params.channelCount;
      if (channels != null && channels > 0) _channels = channels;
    });
    return player;
  }

  Future<void> _configure(Player player, String fifoPath) async {
    final platform = player.platform;
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

  Future<void> _applyFilters(Player player) async {
    await _applyReplayGain(player);
    await _applyEqualizer(player);
  }

  Future<void> _applyReplayGain(Player? player) async {
    final platform = player?.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('replaygain', _replayGain.mpvValue);
    }
  }

  Future<void> _applyEqualizer(Player? player) async {
    final platform = player?.platform;
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
        // Drain extra so mpv's fwrite cannot fill the pipe and block.
        final drain = bytesWanted < 65536 ? 65536 : bytesWanted;
        final bytes = await fifo.read(drain);
        if (!_running) break;
        if (bytes.isNotEmpty && !_hold) {
          final keep = _analyzer.fftSize * _channels * 4;
          final slice = bytes.length > keep
              ? bytes.sublist(bytes.length - keep)
              : bytes;
          final frame = _analyzer.addInterleavedFloat32(
            slice,
            channels: _channels,
          );
          if (frame != null && !_bands.isClosed) {
            _bands.add(frame);
          }
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
