import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

/// media_kit may probe OSC and disk cache features which Studio does not use.
/// Those failures do not affect audio playback.
@visibleForTesting
bool isBenignMpvLog({required String prefix, required String text}) {
  if (text.contains('Failed to create file cache')) return true;
  if (text.contains('property not found') && text.contains('osc')) return true;
  return false;
}

class MediaKitAudioEngine implements AudioEngine {
  MediaKitAudioEngine({Player? player})
    : _primary = player ?? _createAudiblePlayer() {
    _front = _primary;
    _ui = _primary;
    _bind(_primary);
  }

  static const _tick = Duration(milliseconds: 16);
  static const _eqDelay = Duration(milliseconds: 16);
  static const _readinessTimeout = Duration(seconds: 5);

  static Player _createAudiblePlayer() => Player(
    configuration: const PlayerConfiguration(vo: 'null', title: 'Studio'),
  );

  final Player _primary;
  final Map<Player, Future<void>> _configuration =
      Map<Player, Future<void>>.identity();
  final Set<Player> _loadedPlayers = Set<Player>.identity();
  final Map<Player, List<double>> _appliedEqGains =
      Map<Player, List<double>>.identity();
  final Map<Player, double> _appliedEqPreamp = Map<Player, double>.identity();
  final Map<Player, double> _appliedEqPeak = Map<Player, double>.identity();
  final Map<Player, double> _mixFractions = Map<Player, double>.identity();
  final Map<Player, int> _playerOperations = Map<Player, int>.identity();
  final Map<Player, Completer<void>> _playerCancellations =
      Map<Player, Completer<void>>.identity();
  Player? _secondary;

  late Player _front;
  late Player _ui;
  Player? _outgoing;
  Duration _crossfade = Duration.zero;
  double _userVolume = 0.8;
  ReplayGainMode _replayGain = ReplayGainMode.off;
  List<double> _eqGains = List<double>.from(Equalizer.flat);
  var _eqPreamp = 0.0;
  var _eqPeak = 0.0;
  var _eqPeakRevision = 0;
  Timer? _eqDebounce;
  Future<void> _eqApplyTail = Future<void>.value();
  var _eqRevision = 0;
  var _eqMissingLogged = false;
  Uri? _prepared;
  Player? _preparedPlayer;
  int? _preparedOperation;
  Uri? _preparingUri;
  Player? _preparingPlayer;
  Future<bool>? _prepareFuture;
  var _prepareGeneration = 0;
  var _transportGeneration = 0;
  var _started = false;
  var _paused = false;
  var _fading = false;
  Duration _fadeDuration = Duration.zero;
  Duration _fadeElapsed = Duration.zero;
  Stopwatch? _fadeClock;
  Timer? _fadeTimer;
  double? _pendingFadeT;
  Future<void>? _fadeDrain;
  Future<void>? _fadeCleanup;
  var _fadeGeneration = 0;
  var _seekGen = 0;
  var _disposed = false;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _spectrum = StreamController<List<double>>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];

  Player _ensureSecondary() {
    final existing = _secondary;
    if (existing != null) return existing;
    final player = _createAudiblePlayer();
    _secondary = player;
    _bind(player);
    return player;
  }

  Player get _idle {
    final secondary = _ensureSecondary();
    return identical(_front, _primary) ? secondary : _primary;
  }

  @override
  Future<void> play(Uri uri) {
    final request = ++_transportGeneration;
    return _openOnPrimary(uri, play: true, transportGeneration: request);
  }

  @override
  Future<void> load(Uri uri) {
    final request = ++_transportGeneration;
    return _openOnPrimary(uri, play: false, transportGeneration: request);
  }

  Future<void> _openOnPrimary(
    Uri uri, {
    required bool play,
    required int transportGeneration,
  }) async {
    if (!_isTransportCurrent(transportGeneration)) return;
    _invalidatePreparation();
    await _cancelFade(snapIncoming: false);
    if (!_isTransportCurrent(transportGeneration)) return;
    await _stopPlayer(_secondary);
    if (!_isTransportCurrent(transportGeneration)) return;
    _front = _primary;
    _ui = _primary;
    _started = true;
    _paused = !play;
    _fading = false;
    int? operation;
    do {
      operation = await _startAudible(
        _primary,
        uri: uri,
        volume: 1,
        play: play,
      );
    } while (operation == null && _isTransportCurrent(transportGeneration));
    if (!_isTransportCurrent(transportGeneration)) return;
    if (!play) _emitPlaying(false);
  }

  @override
  Future<void> prepare(Uri uri) async {
    if (_crossfade <= Duration.zero || !_started || _fading) return;
    final preparedPlayer = _preparedPlayer;
    final preparedOperation = _preparedOperation;
    if (_prepared == uri &&
        preparedPlayer != null &&
        preparedOperation != null &&
        _isPlayerOperationCurrent(preparedPlayer, preparedOperation)) {
      return;
    }

    final pending = _prepareFuture;
    if (pending != null && _preparingUri == uri) {
      await pending;
      return;
    }

    _invalidatePreparation();
    if (_crossfade <= Duration.zero || !_started) return;
    final requestGeneration = _prepareGeneration;
    final idle = _idle;
    _preparingUri = uri;
    _preparingPlayer = idle;
    late final Future<bool> tracked;
    tracked =
        _startAudible(
              idle,
              uri: uri,
              volume: 0,
              play: false,
              preparationGeneration: requestGeneration,
            )
            .then((operation) {
              if (operation == null ||
                  requestGeneration != _prepareGeneration ||
                  !_started ||
                  _crossfade <= Duration.zero ||
                  !_isPlayerOperationCurrent(idle, operation)) {
                return false;
              }
              _prepared = uri;
              _preparedPlayer = idle;
              _preparedOperation = operation;
              return true;
            })
            .whenComplete(() {
              if (identical(_prepareFuture, tracked)) {
                _prepareFuture = null;
                _preparingUri = null;
                _preparingPlayer = null;
              }
            });
    _prepareFuture = tracked;
    await tracked;
  }

  @override
  Future<void> crossfadeTo(Uri uri) async {
    final request = ++_transportGeneration;
    if (!_started || _paused || _crossfade <= Duration.zero || _fading) {
      return _openOnPrimary(uri, play: !_paused, transportGeneration: request);
    }
    if (_prepared != uri) {
      await prepare(uri);
    }
    if (!_isTransportCurrent(request)) return;
    if (!_started) return;
    if (_paused) {
      return _openOnPrimary(uri, play: false, transportGeneration: request);
    }
    if (_crossfade <= Duration.zero || _fading || _prepared != uri) {
      return _openOnPrimary(uri, play: true, transportGeneration: request);
    }
    final incoming = _preparedPlayer;
    final incomingOperation = _preparedOperation;
    if (incoming == null ||
        incomingOperation == null ||
        !_isPlayerOperationCurrent(incoming, incomingOperation)) {
      return _openOnPrimary(uri, play: true, transportGeneration: request);
    }

    final playbackStarted = _waitUntilPlaybackStarts(
      incoming,
      incomingOperation,
    );
    await _setPaused(incoming, false);
    if (!_isTransportCurrent(request)) return;
    final ready = await playbackStarted;
    if (!_isTransportCurrent(request)) return;
    if (!ready || !_isPlayerOperationCurrent(incoming, incomingOperation)) {
      return _openOnPrimary(uri, play: true, transportGeneration: request);
    }
    if (_paused) {
      final promoted = await _promotePreparedWhilePaused(
        incoming,
        incomingOperation,
        transportGeneration: request,
      );
      if (!promoted && _isTransportCurrent(request)) {
        await _openOnPrimary(uri, play: false, transportGeneration: request);
      }
      return;
    }
    if (_crossfade <= Duration.zero || _fading) {
      return _openOnPrimary(uri, play: true, transportGeneration: request);
    }

    _invalidatePreparation(cancelPending: false);
    _outgoing = _front;
    _ui = incoming;
    _fading = true;
    _fadeDuration = _crossfade;
    _fadeElapsed = Duration.zero;
    _fadeClock = Stopwatch()..start();
    _fadeGeneration++;
    _applyFadeGains(0);
    _startFadeTimer();
  }

  @override
  Future<void> pause() async {
    if (!_started) return;
    _paused = true;
    _pauseFadeClock();
    _emitPlaying(false);
    final targets = <Player>{_front};
    if (_fading || _fadeCleanup != null || _outgoing != null) {
      targets.add(_ui);
      final outgoing = _outgoing;
      if (outgoing != null) targets.add(outgoing);
    }
    await Future.wait([for (final player in targets) _setPaused(player, true)]);
  }

  @override
  Future<void> resume() async {
    if (!_started) return;
    _paused = false;
    _emitPlaying(true);
    if (_fading || _fadeCleanup != null || _outgoing != null) {
      final outgoing = _outgoing;
      await Future.wait([
        _setPaused(_ui, false),
        if (outgoing != null) _setPaused(outgoing, false),
      ]);
      _resumeFadeClock();
      _startFadeTimer();
    } else {
      await _setPaused(_front, false);
    }
  }

  @override
  Future<void> stop() async {
    final request = ++_transportGeneration;
    await _cancelFade(snapIncoming: false);
    if (!_isTransportCurrent(request)) return;
    _started = false;
    _paused = true;
    _invalidatePreparation();
    await Future.wait([_stopPlayer(_primary), _stopPlayer(_secondary)]);
    if (!_isTransportCurrent(request)) return;
    _front = _primary;
    _ui = _primary;
    _emitPlaying(false);
  }

  @override
  Future<void> seek(Duration position) async {
    final gen = ++_seekGen;
    final transport = _transportGeneration;
    if (_fading) await _cancelFade(snapIncoming: true);
    if (gen != _seekGen || !_isTransportCurrent(transport)) return;
    final target = _front;
    final operation = _playerOperations[target];
    if (operation == null || !_isPlayerOperationCurrent(target, operation)) {
      return;
    }
    await target.seek(position);
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
    if (!_started) return;
    await Future.wait([
      for (final player in List<Player>.of(_loadedPlayers))
        _applyReplayGain(player),
    ]);
  }

  @override
  Future<void> setEqualizer(List<double> gains, {double preamp = 0}) async {
    _eqGains = Equalizer.normalizeGains(gains);
    _eqPreamp = Equalizer.clampGain(preamp);
    final revision = ++_eqRevision;
    _eqDebounce?.cancel();
    _eqDebounce = Timer(_eqDelay, () {
      if (_disposed || revision != _eqRevision) return;
      _refreshEqualizerPeak();
      if (_started) _queueEqualizerApply(revision);
    });
  }

  @override
  Future<void> setCrossfade(Duration duration) async {
    if (duration <= Duration.zero) {
      _crossfade = Duration.zero;
      if (_fading || _fadeCleanup != null) {
        await _cancelFade(snapIncoming: true);
        return;
      }
      _invalidatePreparation();
      if (_secondary != null) {
        final idle = identical(_front, _primary) ? _secondary : _primary;
        if (!identical(idle, _front)) {
          await _stopPlayer(idle);
        }
      }
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
    _disposed = true;
    _transportGeneration++;
    _eqRevision++;
    _fadeTimer?.cancel();
    _eqDebounce?.cancel();
    _invalidatePreparation();
    _invalidatePlayerOperation(_primary);
    final secondary = _secondary;
    if (secondary != null) _invalidatePlayerOperation(secondary);
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_position.close());
    unawaited(_duration.close());
    unawaited(_playing.close());
    unawaited(_completed.close());
    unawaited(_spectrum.close());
    unawaited(_primary.dispose());
    if (secondary != null) unawaited(secondary.dispose());
  }

  void _bind(Player player) {
    _subs.add(
      player.stream.log.listen((log) {
        if (isBenignMpvLog(prefix: log.prefix, text: log.text)) return;
        _noteMissingEqualizer(log.text);
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
        if (_fading) {
          if (identical(player, _outgoing) || identical(player, _ui)) {
            unawaited(_finishFade());
          }
          return;
        }
        // A completed event from a player being snapped/stopped must never
        // advance the queue during fade cleanup.
        if (_fadeCleanup != null) return;
        if (!_fading && identical(player, _front) && !_completed.isClosed) {
          _completed.add(null);
        }
      }),
    );
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    if (!_fading || _paused) return;
    final clock = _fadeClock ??= Stopwatch();
    if (!clock.isRunning) clock.start();
    _fadeTimer = Timer.periodic(_tick, (_) {
      final t = _fadeT;
      _applyFadeGains(t);
      if (t >= 1) unawaited(_finishFade());
    });
  }

  void _pauseFadeClock() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    final clock = _fadeClock;
    if (clock == null) return;
    _fadeElapsed += clock.elapsed;
    clock.stop();
    clock.reset();
  }

  void _resumeFadeClock() {
    if (!_fading) return;
    final clock = _fadeClock ??= Stopwatch();
    if (!clock.isRunning) clock.start();
  }

  double get _fadeT {
    final total = _fadeDuration.inMicroseconds;
    if (total <= 0) return 1;
    final elapsed = _fadeElapsed + (_fadeClock?.elapsed ?? Duration.zero);
    return (elapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }

  void _applyFadeGains(double t) {
    _pendingFadeT = t.clamp(0.0, 1.0);
    if (_fadeDrain != null) return;
    late final Future<void> drain;
    drain = _drainFadeGains().whenComplete(() {
      if (identical(_fadeDrain, drain)) _fadeDrain = null;
      if (_pendingFadeT != null && _fading) _applyFadeGains(_pendingFadeT!);
    });
    _fadeDrain = drain;
    unawaited(drain);
  }

  Future<void> _drainFadeGains() async {
    while (_pendingFadeT != null) {
      final t = _pendingFadeT!;
      _pendingFadeT = null;
      final generation = _fadeGeneration;
      if (!_fading) return;
      final outgoing = _outgoing;
      if (outgoing == null) return;
      final pair = Crossfade.headroomSafeGains(t);
      await Future.wait([
        _setPlayerVolume(outgoing, pair.outgoing),
        _setPlayerVolume(_ui, pair.incoming),
      ]);
      if (generation != _fadeGeneration) return;
    }
  }

  Future<void> _stopFadeScheduler() async {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fadeClock?.stop();
    _fadeClock = null;
    _fadeGeneration++;
    _pendingFadeT = null;
    final drain = _fadeDrain;
    if (drain != null) await drain;
  }

  Future<void> _finishFade() {
    final pending = _fadeCleanup;
    if (pending != null) return pending;
    if (!_fading) return Future<void>.value();
    _fading = false;
    late final Future<void> cleanup;
    cleanup = _finishFadeCleanup().whenComplete(() {
      if (identical(_fadeCleanup, cleanup)) {
        _fadeCleanup = null;
        if (_front.state.completed && !_completed.isClosed) {
          _completed.add(null);
        }
      }
    });
    _fadeCleanup = cleanup;
    return cleanup;
  }

  Future<void> _finishFadeCleanup() async {
    await _stopFadeScheduler();
    final outgoing = _outgoing;
    _outgoing = null;
    _front = _ui;
    await _setPlayerVolume(_front, 1);
    if (outgoing != null && !identical(outgoing, _front)) {
      await _setPlayerVolume(outgoing, 0);
      await _stopPlayer(outgoing);
    }
  }

  Future<void> _cancelFade({required bool snapIncoming}) {
    final pending = _fadeCleanup;
    if (pending != null) return pending;
    if (!_fading) return Future<void>.value();
    _fading = false;
    late final Future<void> cleanup;
    cleanup = _cancelFadeCleanup(snapIncoming: snapIncoming).whenComplete(() {
      if (identical(_fadeCleanup, cleanup)) _fadeCleanup = null;
    });
    _fadeCleanup = cleanup;
    return cleanup;
  }

  Future<void> _cancelFadeCleanup({required bool snapIncoming}) async {
    await _stopFadeScheduler();
    final outgoing = _outgoing;
    final incoming = _ui;
    _outgoing = null;
    if (snapIncoming) {
      _front = incoming;
      await _setPlayerVolume(incoming, 1);
      if (outgoing != null && !identical(outgoing, incoming)) {
        await _setPlayerVolume(outgoing, 0);
        await _stopPlayer(outgoing);
      }
    } else {
      _ui = _front;
      await _setPlayerVolume(_front, 1);
      if (incoming != _front) {
        await _setPlayerVolume(incoming, 0);
        await _stopPlayer(incoming);
      }
    }
    _invalidatePreparation();
  }

  void _invalidatePreparation({bool cancelPending = true}) {
    _prepareGeneration++;
    _prepared = null;
    _preparedPlayer = null;
    _preparedOperation = null;
    if (!cancelPending) return;
    final preparingPlayer = _preparingPlayer;
    if (preparingPlayer != null) {
      _invalidatePlayerOperation(preparingPlayer);
    }
    _prepareFuture = null;
    _preparingUri = null;
    _preparingPlayer = null;
  }

  Future<bool> _promotePreparedWhilePaused(
    Player incoming,
    int operation, {
    required int transportGeneration,
  }) async {
    if (!_isTransportCurrent(transportGeneration) ||
        !_isPlayerOperationCurrent(incoming, operation)) {
      return false;
    }
    await _setPaused(incoming, true);
    if (!_isTransportCurrent(transportGeneration) ||
        !_isPlayerOperationCurrent(incoming, operation)) {
      return false;
    }

    _invalidatePreparation(cancelPending: false);
    final outgoing = _front;
    _outgoing = null;
    _front = incoming;
    _ui = incoming;
    await _setPlayerVolume(incoming, 1);
    if (!_isTransportCurrent(transportGeneration) ||
        !_isPlayerOperationCurrent(incoming, operation)) {
      return false;
    }
    if (!identical(outgoing, incoming)) {
      await _setPlayerVolume(outgoing, 0);
      if (!_isTransportCurrent(transportGeneration)) return false;
      await _stopPlayer(outgoing);
      if (!_isTransportCurrent(transportGeneration)) return false;
    }
    await _setPaused(incoming, _paused);
    if (_isTransportCurrent(transportGeneration)) {
      _emitPlaying(!_paused);
      return true;
    }
    return false;
  }

  Future<bool> _waitUntilAudioReady(Player player, int operation) {
    return _waitForPlayerSignal(
      player,
      operation,
      description: 'audio decoder',
      subscribe: (complete) => player.stream.audioParams.listen((params) {
        final sampleRate = params.sampleRate ?? 0;
        final channels = params.channelCount ?? 0;
        if (sampleRate > 0 &&
            (channels > 0 || (params.channels?.isNotEmpty ?? false))) {
          complete(true);
        }
      }),
    );
  }

  Future<bool> _waitUntilPlaybackStarts(Player player, int operation) {
    if (_isPlayerOperationCurrent(player, operation) &&
        player.state.position > Duration.zero) {
      return Future<bool>.value(true);
    }
    return _waitForPlayerSignal(
      player,
      operation,
      description: 'playback clock',
      subscribe: (complete) => player.stream.position.listen((position) {
        if (position > Duration.zero) complete(true);
      }),
    );
  }

  Future<bool> _waitForPlayerSignal(
    Player player,
    int operation, {
    required String description,
    required StreamSubscription<dynamic> Function(void Function(bool) complete)
    subscribe,
  }) {
    if (!_isPlayerOperationCurrent(player, operation)) {
      return Future<bool>.value(false);
    }
    final result = Completer<bool>();
    StreamSubscription<dynamic>? signalSubscription;
    StreamSubscription<String>? errorSubscription;
    StreamSubscription<bool>? completedSubscription;
    StreamSubscription<void>? cancellationSubscription;
    Timer? timeout;

    void complete(bool value) {
      if (!result.isCompleted) result.complete(value);
    }

    signalSubscription = subscribe(complete);
    errorSubscription = player.stream.error.listen((error) {
      debugPrint('Studio audio $description failed: $error');
      complete(false);
    });
    completedSubscription = player.stream.completed.listen((completed) {
      if (completed) complete(false);
    });
    final cancellation = _playerCancellations[player];
    if (cancellation != null) {
      cancellationSubscription = cancellation.future.asStream().listen((_) {
        complete(false);
      });
    }
    timeout = Timer(_readinessTimeout, () {
      debugPrint('Studio audio timed out waiting for $description.');
      complete(false);
    });

    return result.future.whenComplete(() async {
      timeout?.cancel();
      await signalSubscription?.cancel();
      await errorSubscription?.cancel();
      await completedSubscription?.cancel();
      await cancellationSubscription?.cancel();
    });
  }

  /// Open [uri] on a real platform output. The graph is replaced only while
  /// this player is stopped; live EQ changes use `af-command` instead.
  Future<int?> _startAudible(
    Player player, {
    required Uri uri,
    required double volume,
    bool play = true,
    int? preparationGeneration,
  }) async {
    if (_disposed ||
        (preparationGeneration != null &&
            preparationGeneration != _prepareGeneration)) {
      return null;
    }
    final operation = _beginPlayerOperation(player);
    bool isCurrent() =>
        _isPlayerOperationCurrent(player, operation) &&
        (preparationGeneration == null ||
            preparationGeneration == _prepareGeneration);

    await _ensureConfigured(player);
    if (!isCurrent()) return null;
    await _setPlayerVolume(player, 0);
    if (!isCurrent()) return null;
    _forgetPlayerState(player);
    await player.stop();
    if (!isCurrent()) return null;

    final replayGain = _replayGain;
    await _applyReplayGain(player);
    if (!isCurrent()) return null;
    var graphRevision = await _installEqualizerGraph(
      player,
      operation: operation,
    );
    if (graphRevision == null || !isCurrent()) return null;

    final audible = play && volume > 0;
    final ready = _waitUntilAudioReady(player, operation);
    try {
      await player.open(Media(uri.toString()), play: false);
    } on Object {
      if (isCurrent()) _invalidatePlayerOperation(player);
      rethrow;
    }
    if (!isCurrent()) return null;
    final audioReady = await ready;
    if (!isCurrent()) return null;
    if (!audioReady) {
      throw StateError('Timed out while initializing audio for $uri');
    }
    if (replayGain != _replayGain) {
      await _applyReplayGain(player);
      if (!isCurrent()) return null;
    }
    if (graphRevision != _eqRevision) {
      graphRevision = await _installEqualizerGraph(
        player,
        operation: operation,
      );
      if (graphRevision == null || !isCurrent()) return null;
    }
    _loadedPlayers.add(player);
    if (graphRevision != _eqRevision) {
      _queueEqualizerApply(_eqRevision);
    }
    await _setPlayerVolume(player, volume);
    if (!isCurrent()) return null;
    if (audible) {
      await _setPaused(player, false);
    } else {
      await _setPaused(player, true);
    }
    if (!isCurrent()) return null;
    return operation;
  }

  Future<void> _ensureConfigured(Player player) => _configuration.putIfAbsent(
    player,
    () => _configureNative(player.platform),
  );

  static Future<void> _configureNative(Object? platform) async {
    if (platform is! NativePlayer) return;
    if (Platform.isWindows) {
      await _setNativeProperty(platform, 'ao', 'wasapi');
    }
    await _setNativeProperty(platform, 'audio-exclusive', 'no');
    await _setNativeProperty(platform, 'mute', 'no');
    // media_kit turns on `cache-on-disk`; this libmpv then logs
    // `lavf/mf: Failed to create file cache` and the next open can stall.
    await _setNativeProperty(platform, 'cache-on-disk', 'no');
    await _setNativeProperty(platform, 'cache', 'no');
  }

  static Future<void> _setNativeProperty(
    NativePlayer player,
    String name,
    String value,
  ) => player.command(['set', name, value]);

  Future<int?> _installEqualizerGraph(
    Player player, {
    required int operation,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return _eqRevision;
    _ensureEqualizerPeakCurrent();
    final revision = _eqRevision;
    final gains = Equalizer.normalizeGains(_eqGains);
    final preamp = _eqPreamp;
    final peak = _eqPeak;
    await _setNativeProperty(platform, 'af', Equalizer.afFilter(gains));
    if (!_isPlayerOperationCurrent(player, operation)) return null;
    _appliedEqGains[player] = gains;
    _appliedEqPreamp[player] = preamp;
    _appliedEqPeak[player] = peak;
    return revision;
  }

  void _queueEqualizerApply(int revision) {
    unawaited(_enqueueEqualizerApply(revision));
  }

  void _refreshEqualizerPeak() {
    _eqPeak = Equalizer.peakGainDb(_eqGains);
    _eqPeakRevision = _eqRevision;
  }

  void _ensureEqualizerPeakCurrent() {
    if (_eqPeakRevision != _eqRevision) _refreshEqualizerPeak();
  }

  Future<void> _enqueueEqualizerApply(int revision, {Player? player}) {
    final previous = _eqApplyTail;
    final task = () async {
      await previous;
      if (_disposed || revision != _eqRevision) return;
      final targets = player == null
          ? List<Player>.of(_loadedPlayers)
          : <Player>[player];
      _ensureEqualizerPeakCurrent();
      final gains = Equalizer.normalizeGains(_eqGains);
      final preamp = _eqPreamp;
      final peak = _eqPeak;
      try {
        await Future.wait([
          for (final target in targets)
            if (_loadedPlayers.contains(target))
              _applyEqualizer(
                target,
                revision,
                gains: gains,
                preamp: preamp,
                peak: peak,
              ),
        ]);
      } on Object catch (error, stack) {
        debugPrint('Studio EQ update failed: $error\n$stack');
      }
    }();
    _eqApplyTail = task;
    return task;
  }

  Future<void> _applyEqualizer(
    Player player,
    int revision, {
    required List<double> gains,
    required double preamp,
    required double peak,
  }) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    final operation = _playerOperations[player];
    if (operation == null) return;
    if (_disposed ||
        revision != _eqRevision ||
        !_loadedPlayers.contains(player) ||
        !_isPlayerOperationCurrent(player, operation)) {
      return;
    }

    final previous = _appliedEqGains[player];
    final previousPreamp = _appliedEqPreamp[player] ?? preamp;
    if (!player.state.playing) {
      await _setNativeProperty(platform, 'af', Equalizer.afFilter(gains));
      if (!_loadedPlayers.contains(player) ||
          !_isPlayerOperationCurrent(player, operation)) {
        return;
      }
      _appliedEqGains[player] = List<double>.from(gains);
      _appliedEqPreamp[player] = preamp;
      _appliedEqPeak[player] = peak;
      await _setPlayerVolume(player, _mixFractions[player] ?? 0);
      return;
    }

    final transitionPeak = Equalizer.transitionPeakGainDb(previous, gains);
    // Move to the more conservative of the old and new output gains before
    // changing coefficients. This prevents a boosted curve from clipping in
    // the tiny window while the asynchronous commands are being applied.
    _appliedEqPreamp[player] = previousPreamp < preamp
        ? previousPreamp
        : preamp;
    _appliedEqPeak[player] = transitionPeak;
    await _setPlayerVolume(player, _mixFractions[player] ?? 0);
    if (!_isPlayerOperationCurrent(player, operation)) return;

    final commands = Equalizer.afCommands(previous, gains);
    for (final command in commands) {
      await platform.command(command);
      if (!_loadedPlayers.contains(player) ||
          !_isPlayerOperationCurrent(player, operation)) {
        return;
      }
    }

    _appliedEqGains[player] = List<double>.from(gains);
    _appliedEqPreamp[player] = preamp;
    _appliedEqPeak[player] = peak;
    await _setPlayerVolume(player, _mixFractions[player] ?? 0);
  }

  void _noteMissingEqualizer(String text) {
    if (_eqMissingLogged) return;
    final lower = text.toLowerCase();
    if (!lower.contains('equalizer') && !lower.contains('aresample')) return;
    if (!lower.contains('no such') &&
        !lower.contains('not found') &&
        !lower.contains('failed')) {
      return;
    }
    _eqMissingLogged = true;
    debugPrint('Studio EQ: the packaged libmpv/FFmpeg filter graph failed.');
  }

  Future<void> _applyReplayGain(Player player) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      await _setNativeProperty(platform, 'replaygain', _replayGain.mpvValue);
    }
  }

  Future<void> _setPlayerVolume(Player player, double fraction) {
    final mix = fraction.clamp(0.0, 1.0).toDouble();
    _mixFractions[player] = mix;
    final preamp = _appliedEqPreamp[player] ?? _eqPreamp;
    final peak = _appliedEqPeak[player] ?? _eqPeak;
    final requested = _userVolume * Equalizer.preampLinear(preamp);
    final ceiling = math.pow(10, -peak / 20).toDouble();
    final percent = (math.min(requested, ceiling) * mix * 100)
        .clamp(0.0, 100.0)
        .toDouble();
    return player.setVolume(percent);
  }

  Future<void> _stopPlayer(Player? player) async {
    if (player == null) return;
    _beginPlayerOperation(player);
    _forgetPlayerState(player);
    await player.stop();
  }

  void _forgetPlayerState(Player player) {
    _loadedPlayers.remove(player);
    _appliedEqGains.remove(player);
    _appliedEqPreamp.remove(player);
    _appliedEqPeak.remove(player);
    _mixFractions.remove(player);
  }

  int _beginPlayerOperation(Player player) {
    final cancellation = _playerCancellations[player];
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    final operation = (_playerOperations[player] ?? 0) + 1;
    _playerOperations[player] = operation;
    _playerCancellations[player] = Completer<void>();
    return operation;
  }

  void _invalidatePlayerOperation(Player player) {
    _beginPlayerOperation(player);
  }

  bool _isPlayerOperationCurrent(Player player, int operation) {
    return !_disposed && _playerOperations[player] == operation;
  }

  bool _isTransportCurrent(int generation) {
    return !_disposed && _transportGeneration == generation;
  }

  /// Uses media_kit's serialized operation lock and waits for libmpv to
  /// acknowledge the state change. The default native configuration dispatches
  /// the underlying command asynchronously, so this never blocks the UI isolate.
  Future<void> _setPaused(Player player, bool paused) {
    return paused ? player.pause() : player.play();
  }

  void _emitPlaying(bool value) {
    if (!_playing.isClosed) _playing.add(value);
  }
}
