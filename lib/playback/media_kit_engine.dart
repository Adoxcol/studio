import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player})
    : _primary = player ?? Player(configuration: _audibleConfig) {
    _front = _primary;
    _ui = _primary;
    _bind(_primary);
  }

  static const _tick = Duration(milliseconds: 50);
  static const _audibleConfig = PlayerConfiguration(
    vo: 'null',
    title: 'Studio',
  );

  final Player _primary;
  Player? _secondary;

  late Player _front;
  late Player _ui;
  Player? _outgoing;
  Duration _crossfade = Duration.zero;
  double _userVolume = 0.8;
  ReplayGainMode _replayGain = ReplayGainMode.off;
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

  Player _ensureSecondary() {
    final existing = _secondary;
    if (existing != null) return existing;
    final player = Player(configuration: _audibleConfig);
    _secondary = player;
    _bind(player);
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
    await _startAudible(_primary, uri: uri, volume: 1);
  }

  @override
  Future<void> prepare(Uri uri) async {
    if (_crossfade <= Duration.zero || !_started) return;
    if (_prepared == uri) return;
    final idle = _idle;
    await _startAudible(idle, uri: uri, volume: 0);
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
      await _startAudible(incoming, uri: uri, volume: 0);
    } else {
      await incoming.play();
    }
    _prepared = null;
    _outgoing = _front;
    _ui = incoming;
    _fading = true;
    _fadeElapsed = Duration.zero;
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
  }

  @override
  Future<void> resume() async {
    _paused = false;
    _emitPlaying(true);
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
    if (_started) unawaited(_applyFilters(_front));
  }

  @override
  Future<void> setEqualizer(List<double> _) async {
    // media_kit's libmpv has no lavfi EQ (`aresample` / `firequalizer`).
    // Setting `af` flushes the decoder, so the playhead jumps on every slider.
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
    unawaited(_position.close());
    unawaited(_duration.close());
    unawaited(_playing.close());
    unawaited(_completed.close());
    unawaited(_spectrum.close());
    _primary.dispose();
    _secondary?.dispose();
  }

  void _bind(Player player) {
    _subs.add(
      player.stream.log.listen((log) {
        debugPrint('mpv ${log.level}: ${log.prefix}: ${log.text}');
      }),
    );
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

  /// Open [uri] on [player] and force a real device. Never set mpv `af` —
  /// this libmpv has no `aresample`/`firequalizer`, and a failed lavfi graph
  /// flushes the decoder (the playhead jumps).
  Future<void> _startAudible(
    Player player, {
    required Uri uri,
    required double volume,
  }) async {
    await _configureOutput(player);
    await player.open(Media(uri.toString()), play: volume > 0);
    await _configureOutput(player);
    if (volume > 0) await player.play();
    await _setPlayerVolume(player, volume);
    await _applyReplayGain(player);
  }

  Future<void> _configureOutput(Player player) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    if (Platform.isWindows) {
      await platform.setProperty('ao', 'wasapi');
    }
    await platform.setProperty('audio-exclusive', 'no');
    await platform.setProperty('mute', 'no');
    await platform.setProperty('ao-mute', 'no');
    await platform.setProperty('ao-volume', '100');
  }

  Future<void> _applyFilters(Player player) async {
    await _applyReplayGain(player);
  }

  Future<void> _applyReplayGain(Player player) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('replaygain', _replayGain.mpvValue);
    }
  }

  Future<void> _setPlayerVolume(Player player, double fraction) {
    return player.setVolume(
      (_userVolume * fraction.clamp(0.0, 1.0) * 100).clamp(0.0, 100.0),
    );
  }

  /// Pauses without blocking the UI isolate. Never uses synchronous
  /// `mpv_set_property_string` on the command queue.
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
