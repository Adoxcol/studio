import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/spectrum_tap.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player, MpvSpectrumTap? spectrumTap})
    : _primary = player ?? Player(),
      _tap = spectrumTap {
    _front = _primary;
    _ui = _primary;
    _bind(_primary);
    if (spectrumTap != null) _bindTap(spectrumTap);
  }

  static const _tick = Duration(milliseconds: 50);

  final Player _primary;
  Player? _secondary;
  MpvSpectrumTap? _tap;

  late Player _front;
  late Player _ui;
  Player? _outgoing;
  Duration _crossfade = Duration.zero;
  double _userVolume = 0.8;
  ReplayGainMode _replayGain = ReplayGainMode.off;
  List<double> _equalizer = Equalizer.flat;
  Uri? _prepared;
  var _started = false;
  var _paused = false;
  var _fading = false;
  Duration _fadeElapsed = Duration.zero;
  Timer? _fadeTimer;
  var _seekGen = 0;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _spectrum = StreamController<List<double>>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<List<double>>? _tapBandsSub;

  MpvSpectrumTap _ensureTap() {
    final existing = _tap;
    if (existing != null) return existing;
    final tap = MpvSpectrumTap();
    _tap = tap;
    tap.rememberReplayGain(_replayGain);
    tap.rememberEqualizer(_equalizer);
    _bindTap(tap);
    return tap;
  }

  void _bindTap(MpvSpectrumTap tap) {
    _tapBandsSub ??= tap.bands.listen((bands) {
      if (!_spectrum.isClosed) _spectrum.add(bands);
    });
  }

  Player _ensureSecondary() {
    final existing = _secondary;
    if (existing != null) return existing;
    final player = Player();
    _secondary = player;
    _bind(player);
    unawaited(_applyFilters(player));
    return player;
  }

  Player get _idle {
    final secondary = _ensureSecondary();
    return identical(_front, _primary) ? secondary : _primary;
  }

  @override
  Future<void> play(Uri uri) async {
    await _cancelFade(snapIncoming: false);
    await _secondary?.stop();
    _front = _primary;
    _ui = _primary;
    _prepared = null;
    _started = true;
    _paused = false;
    _fading = false;
    await _applyFilters(_primary);
    await _setPlayerVolume(_primary, 1);
    await _primary.open(Media(uri.toString()));
    unawaited(_ensureTap().play(uri));
  }

  @override
  Future<void> prepare(Uri uri) async {
    if (_crossfade <= Duration.zero || !_started) return;
    if (_prepared == uri) return;
    final idle = _idle;
    await _applyFilters(idle);
    await _setPlayerVolume(idle, 0);
    await idle.open(Media(uri.toString()));
    await idle.pause();
    _prepared = uri;
  }

  @override
  Future<void> crossfadeTo(Uri uri) async {
    if (!_started || _paused || _crossfade <= Duration.zero || _fading) {
      return play(uri);
    }
    final incoming = _idle;
    if (_prepared != uri) {
      await _applyFilters(incoming);
      await _setPlayerVolume(incoming, 0);
      await incoming.open(Media(uri.toString()));
    } else {
      await incoming.play();
    }
    _prepared = null;
    _outgoing = _front;
    _ui = incoming;
    _fading = true;
    _fadeElapsed = Duration.zero;
    unawaited(_ensureTap().play(uri));
    _applyFadeGains(0);
    _startFadeTimer();
  }

  @override
  Future<void> pause() async {
    _paused = true;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _emitPlaying(false);
    _setPaused(_front, true);
    final outgoing = _outgoing;
    if (outgoing != null) _setPaused(outgoing, true);
    unawaited(_tap?.pause());
  }

  @override
  Future<void> resume() async {
    _paused = false;
    _emitPlaying(true);
    unawaited(_tap?.resume());
    if (_fading) {
      final outgoing = _outgoing;
      if (outgoing != null) _setPaused(outgoing, false);
      _setPaused(_ui, false);
      _startFadeTimer();
    } else {
      _setPaused(_front, false);
    }
  }

  @override
  Future<void> stop() async {
    await _cancelFade(snapIncoming: false);
    _started = false;
    _paused = true;
    _prepared = null;
    await Future.wait([
      _primary.stop(),
      if (_secondary != null) _secondary!.stop(),
      if (_tap != null) _tap!.stop(),
    ]);
    _front = _primary;
    _ui = _primary;
    _emitPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    final gen = ++_seekGen;
    if (_fading) await _cancelFade(snapIncoming: true);
    if (gen != _seekGen) return;
    await _front.seek(position);
    if (gen != _seekGen) return;
    unawaited(_tap?.seek(position) ?? Future.value());
  }

  @override
  Future<void> setVolume(double volume) async {
    _userVolume = volume.clamp(0.0, 1.0);
    if (_fading) {
      _applyFadeGains(_fadeT);
    } else {
      await _setPlayerVolume(_front, 1);
    }
  }

  @override
  Future<void> setReplayGain(ReplayGainMode mode) async {
    _replayGain = mode;
    unawaited(_applyFilters(_primary));
    if (_secondary != null) unawaited(_applyFilters(_secondary!));
    // Never setProperty on the live FFT tap — that deadlocks ao=pcm.
    _tap?.rememberReplayGain(mode);
  }

  @override
  Future<void> setEqualizer(List<double> gains) async {
    _equalizer = List<double>.from(gains);
    unawaited(_applyFilters(_primary));
    if (_secondary != null) unawaited(_applyFilters(_secondary!));
    _tap?.rememberEqualizer(gains);
  }

  @override
  Future<void> setCrossfade(Duration duration) async {
    if (duration <= Duration.zero) {
      _crossfade = Duration.zero;
      return;
    }
    final ms = duration.inMilliseconds.clamp(0, Crossfade.max.inMilliseconds);
    _crossfade = Duration(milliseconds: ms);
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
    _fadeTimer?.cancel();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_tapBandsSub?.cancel());
    unawaited(_position.close());
    unawaited(_duration.close());
    unawaited(_playing.close());
    unawaited(_completed.close());
    unawaited(_spectrum.close());
    _tap?.dispose();
    _primary.dispose();
    _secondary?.dispose();
  }

  void _bind(Player player) {
    _subs.add(
      player.stream.position.listen((value) {
        if (identical(player, _ui) && !_position.isClosed) {
          _position.add(value);
        }
      }),
    );
    _subs.add(
      player.stream.duration.listen((value) {
        if (identical(player, _ui) && !_duration.isClosed) {
          _duration.add(value);
        }
      }),
    );
    _subs.add(
      player.stream.playing.listen((value) {
        if (identical(player, _ui) && !_fading && !_playing.isClosed) {
          _playing.add(value);
        }
      }),
    );
    _subs.add(
      player.stream.completed.where((done) => done).listen((_) {
        if (_fading && identical(player, _outgoing)) {
          unawaited(_finishFade());
          return;
        }
        if (!_fading && identical(player, _front) && !_completed.isClosed) {
          _completed.add(null);
        }
      }),
    );
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = Timer.periodic(_tick, (_) {
      _fadeElapsed += _tick;
      final t = _fadeT;
      _applyFadeGains(t);
      if (t >= 1) unawaited(_finishFade());
    });
  }

  double get _fadeT {
    final total = _crossfade.inMilliseconds;
    if (total <= 0) return 1;
    return (_fadeElapsed.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _applyFadeGains(double t) {
    final pair = Crossfade.gains(t);
    final outgoing = _outgoing;
    if (outgoing != null) unawaited(_setPlayerVolume(outgoing, pair.outgoing));
    unawaited(_setPlayerVolume(_ui, pair.incoming));
  }

  Future<void> _finishFade() async {
    if (!_fading) return;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fading = false;
    final outgoing = _outgoing;
    _outgoing = null;
    _front = _ui;
    await _setPlayerVolume(_front, 1);
    if (outgoing != null && !identical(outgoing, _front)) {
      await outgoing.stop();
    }
  }

  Future<void> _cancelFade({required bool snapIncoming}) async {
    if (!_fading) return;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fading = false;
    final outgoing = _outgoing;
    final incoming = _ui;
    _outgoing = null;
    if (snapIncoming) {
      _front = incoming;
      await _setPlayerVolume(incoming, 1);
      if (outgoing != null && !identical(outgoing, incoming)) {
        await outgoing.stop();
      }
    } else {
      _ui = _front;
      await _setPlayerVolume(_front, 1);
      if (incoming != _front) await incoming.stop();
    }
    _prepared = null;
  }

  Future<void> _applyFilters(Player player) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('replaygain', _replayGain.mpvValue);
      await platform.setProperty('af', Equalizer.afFilter(_equalizer));
    }
  }

  Future<void> _setPlayerVolume(Player player, double fraction) {
    return player.setVolume(
      (_userVolume * fraction.clamp(0.0, 1.0) * 100).clamp(0.0, 100.0),
    );
  }

  /// Pauses without blocking the UI isolate. Never uses synchronous
  /// `mpv_set_property_string` — that deadlocks if mpv is in `ao=pcm`.
  void _setPaused(Player player, bool paused) {
    final platform = player.platform;
    if (platform is NativePlayer) {
      unawaited(
        paused
            ? platform.pause(synchronized: false)
            : platform.play(synchronized: false),
      );
      return;
    }
    unawaited(paused ? player.pause() : player.play());
  }

  void _emitPlaying(bool value) {
    if (!_playing.isClosed) _playing.add(value);
  }
}
