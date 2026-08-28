import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/spectrum_tap.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({
    Player? player,
    Player? secondary,
    MpvSpectrumTap? spectrumTap,
  }) : _primary = player ?? Player(),
       _secondary = secondary ?? Player(),
       _tap = spectrumTap ?? MpvSpectrumTap() {
    _front = _primary;
    _ui = _primary;
    _bind(_primary);
    _bind(_secondary);
  }

  static const _tick = Duration(milliseconds: 50);

  final Player _primary;
  final Player _secondary;
  final MpvSpectrumTap _tap;

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

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  Player get _idle => identical(_front, _primary) ? _secondary : _primary;

  @override
  Future<void> play(Uri uri) async {
    await _cancelFade(snapIncoming: false);
    await _secondary.stop();
    _front = _primary;
    _ui = _primary;
    _prepared = null;
    _started = true;
    _paused = false;
    _fading = false;
    await _applyFilters(_primary);
    await _setPlayerVolume(_primary, 1);
    await _primary.open(Media(uri.toString()));
    unawaited(_tap.play(uri));
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
    unawaited(_tap.play(uri));
    _applyFadeGains(0);
    _startFadeTimer();
  }

  @override
  Future<void> pause() async {
    _paused = true;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    await Future.wait([_primary.pause(), _secondary.pause(), _tap.pause()]);
    _emitPlaying(false);
  }

  @override
  Future<void> resume() async {
    _paused = false;
    if (_fading) {
      await Future.wait([
        _outgoing?.play() ?? Future.value(),
        _ui.play(),
        _tap.resume(),
      ]);
      _startFadeTimer();
    } else {
      await Future.wait([_front.play(), _tap.resume()]);
    }
    _emitPlaying(true);
  }

  @override
  Future<void> stop() async {
    await _cancelFade(snapIncoming: false);
    _started = false;
    _paused = true;
    _prepared = null;
    await Future.wait([_primary.stop(), _secondary.stop(), _tap.stop()]);
    _front = _primary;
    _ui = _primary;
    _emitPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_fading) await _cancelFade(snapIncoming: true);
    await _front.seek(position);
    unawaited(_tap.seek(position));
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
  Future<void> setReplayGain(ReplayGainMode mode) {
    _replayGain = mode;
    return Future.wait([
      _applyFilters(_primary),
      _applyFilters(_secondary),
      _tap.setReplayGain(mode),
    ]);
  }

  @override
  Future<void> setEqualizer(List<double> gains) {
    _equalizer = List<double>.from(gains);
    return Future.wait([
      _applyFilters(_primary),
      _applyFilters(_secondary),
      _tap.setEqualizer(gains),
    ]);
  }

  @override
  Future<void> setCrossfade(Duration duration) async {
    _crossfade = duration < Duration.zero ? Duration.zero : duration;
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
  Stream<List<double>> get spectrum => _tap.bands;

  @override
  void dispose() {
    _fadeTimer?.cancel();
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_position.close());
    unawaited(_duration.close());
    unawaited(_playing.close());
    unawaited(_completed.close());
    _tap.dispose();
    _primary.dispose();
    _secondary.dispose();
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

  void _emitPlaying(bool value) {
    if (!_playing.isClosed) _playing.add(value);
  }
}
