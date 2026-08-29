import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/playback/playback_session.dart';
import 'package:studio/playback/playback_session_provider.dart';
import 'package:studio/playback/playback_session_store.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/providers/resolver_registry.dart';
import 'package:studio/state/library_providers.dart';

@immutable
class PlaybackUiState {
  const PlaybackUiState({
    this.trackId,
    this.title = 'Not playing',
    this.artist,
    this.album,
    this.artworkPath,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 0.8,
    this.repeat = QueueRepeatMode.off,
    this.shuffle = false,
    this.queueIds = const [],
  });

  final int? trackId;
  final String title;
  final String? artist;
  final String? album;
  final String? artworkPath;
  final bool playing;
  final Duration position;
  final Duration duration;
  final double volume;
  final QueueRepeatMode repeat;
  final bool shuffle;
  final List<int> queueIds;

  List<int> get upcomingIds {
    final id = trackId;
    if (id == null || queueIds.isEmpty) return const [];
    final index = queueIds.indexOf(id);
    if (index < 0 || index >= queueIds.length - 1) return const [];
    return queueIds.sublist(index + 1);
  }

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlaybackUiState copyWith({
    int? trackId,
    String? title,
    String? artist,
    String? album,
    String? artworkPath,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? volume,
    QueueRepeatMode? repeat,
    bool? shuffle,
    List<int>? queueIds,
    bool clearArtist = false,
    bool clearAlbum = false,
    bool clearArtwork = false,
  }) {
    return PlaybackUiState(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: clearArtist ? null : artist ?? this.artist,
      album: clearAlbum ? null : album ?? this.album,
      artworkPath: clearArtwork ? null : artworkPath ?? this.artworkPath,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      repeat: repeat ?? this.repeat,
      shuffle: shuffle ?? this.shuffle,
      queueIds: queueIds ?? this.queueIds,
    );
  }
}

class PlaybackController extends Notifier<PlaybackUiState> {
  late final AudioEngine _engine;
  late final StudioDatabase _db;
  late final ResolverRegistry _resolvers;
  late final PlaybackSessionStore _sessionStore;
  final queue = PlaybackQueue();
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _positionFlush;
  Duration? _queuedPosition;
  var _crossfadeArmed = false;
  var _opening = false;
  var _openAgain = false;
  var _openCrossfade = false;
  var _holdPosition = false;
  var _scrubbing = false;
  Duration? _seekFrom;
  Duration? _seekTarget;
  var _closeTicks = 0;
  var _seekGen = 0;
  Timer? _seekHold;
  var _wantPlaying = false;
  Timer? _sessionSave;
  DateTime? _sessionSavedAt;
  var _restoring = false;

  @override
  PlaybackUiState build() {
    _engine = ref.watch(audioEngineProvider);
    _db = ref.watch(studioDatabaseProvider);
    _resolvers = ref.watch(resolverRegistryProvider);
    _sessionStore = ref.watch(playbackSessionStoreProvider);
    ref.listen(playbackSettingsProvider.select((s) => s.replayGain), (_, mode) {
      unawaited(_engine.setReplayGain(mode));
    });
    unawaited(
      _engine.setReplayGain(ref.read(playbackSettingsProvider).replayGain),
    );
    ref.listen(playbackSettingsProvider.select((s) => s.activeEqualizerGains), (
      _,
      gains,
    ) {
      unawaited(_engine.setEqualizer(gains));
    });
    unawaited(
      _engine.setEqualizer(
        ref.read(playbackSettingsProvider).activeEqualizerGains,
      ),
    );
    ref.listen(playbackSettingsProvider.select((s) => s.crossfade), (
      _,
      duration,
    ) {
      unawaited(_engine.setCrossfade(duration));
    });
    unawaited(
      _engine.setCrossfade(ref.read(playbackSettingsProvider).crossfade),
    );

    _subs.add(_engine.position.listen(_onPosition));
    _subs.add(
      _engine.duration.listen((value) {
        if (value <= Duration.zero) return;
        if (state.duration == value) return;
        state = state.copyWith(duration: value);
      }),
    );
    _subs.add(
      _engine.playing.listen((value) {
        if (value != _wantPlaying) return;
        if (state.playing != value) {
          state = state.copyWith(playing: value);
        }
      }),
    );
    _subs.add(
      _engine.completed.listen((_) {
        if (_opening || _restoring) return;
        unawaited(skipNext());
      }),
    );

    ref.onDispose(() {
      _sessionSave?.cancel();
      _positionFlush?.cancel();
      _seekHold?.cancel();
      for (final sub in _subs) {
        unawaited(sub.cancel());
      }
    });

    unawaited(_restoreSession());
    return const PlaybackUiState();
  }

  void _onPosition(Duration value) {
    if (_holdPosition || _scrubbing) return;
    if (_seekTarget != null) {
      if (_tickIsStale(value)) {
        _closeTicks = 0;
        return;
      }
      _closeTicks++;
      _applyPosition(value, followPlayback: false);
      if (_closeTicks >= 2) _clearSeekLock();
      return;
    }
    _applyPosition(value, followPlayback: true);
  }

  bool _tickIsStale(Duration value) {
    final target = _seekTarget;
    if (target == null) return false;
    final toTarget = (value - target).abs();
    final from = _seekFrom;
    if (from != null) {
      final toFrom = (value - from).abs();
      if (toFrom + const Duration(milliseconds: 250) < toTarget) {
        return true;
      }
    }
    return toTarget > const Duration(seconds: 2);
  }

  void _applyPosition(Duration value, {required bool followPlayback}) {
    if (value < const Duration(milliseconds: 400)) {
      _crossfadeArmed = false;
    }
    if (!followPlayback) {
      _queuedPosition = null;
      state = state.copyWith(position: value);
      return;
    }
    _queuedPosition = value;
    if (_positionFlush != null) return;
    state = state.copyWith(position: value);
    _queuedPosition = null;
    _positionFlush = Timer(const Duration(milliseconds: 50), () {
      _positionFlush = null;
      final pending = _queuedPosition;
      _queuedPosition = null;
      if (pending == null) return;
      if (_seekTarget != null && _tickIsStale(pending)) return;
      state = state.copyWith(position: pending);
      _scheduleSessionSave();
    });
    unawaited(_considerAutoCrossfade(value));
  }

  void _armSeek(Duration target) {
    _positionFlush?.cancel();
    _positionFlush = null;
    _queuedPosition = null;
    _seekFrom = state.position;
    _seekTarget = target;
    _closeTicks = 0;
    _seekHold?.cancel();
    _seekHold = Timer(const Duration(seconds: 3), _clearSeekLock);
  }

  void _clearSeekLock() {
    _seekTarget = null;
    _seekFrom = null;
    _closeTicks = 0;
    _seekHold?.cancel();
    _seekHold = null;
  }

  void beginScrub() {
    _scrubbing = true;
    _positionFlush?.cancel();
    _positionFlush = null;
    _queuedPosition = null;
  }

  void endScrub() {
    _scrubbing = false;
  }

  Future<void> playTracks(
    List<int> ids, {
    int startIndex = 0,
    bool? shuffle,
  }) async {
    if (ids.isEmpty) return;
    if (shuffle != null) {
      queue.shuffle = shuffle;
    }
    queue.replace(ids, startIndex: startIndex);
    await _openCurrent();
    _scheduleSessionSave(flush: true);
  }

  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= queue.ids.length) return;
    queue.index = index;
    await _openCurrent();
    _scheduleSessionSave(flush: true);
  }

  Future<void> togglePlayPause() async {
    if (state.trackId == null) return;
    final pause = state.playing;
    _wantPlaying = !pause;
    state = state.copyWith(playing: _wantPlaying);
    if (pause) {
      await _engine.pause();
    } else {
      await _engine.resume();
    }
    _scheduleSessionSave(flush: true);
  }

  Future<void> skipNext() async {
    if (!queue.moveNext()) return;
    await _openCurrent(crossfade: true);
    _scheduleSessionSave(flush: true);
  }

  Future<void> skipPrevious() async {
    if (state.position > const Duration(seconds: 3)) {
      _positionFlush?.cancel();
      _positionFlush = null;
      _queuedPosition = null;
      _armSeek(Duration.zero);
      state = state.copyWith(position: Duration.zero);
      await _engine.seek(Duration.zero);
      _scheduleSessionSave(flush: true);
      return;
    }
    if (!queue.movePrevious()) return;
    await _openCurrent();
    _scheduleSessionSave(flush: true);
  }

  Future<void> seekFraction(double fraction) async {
    final total = state.duration;
    if (total <= Duration.zero) return;
    await seekTo(
      Duration(
        milliseconds: (total.inMilliseconds * fraction.clamp(0.0, 1.0)).round(),
      ),
    );
  }

  Future<void> seekTo(Duration position) async {
    final total = state.duration;
    var next = position < Duration.zero ? Duration.zero : position;
    if (total > Duration.zero && next > total) next = total;
    final gen = ++_seekGen;
    _armSeek(next);
    state = state.copyWith(position: next);
    await _engine.seek(next);
    if (gen != _seekGen) return;
    _scheduleSessionSave(flush: true);
  }

  Future<void> setVolume(double volume) async {
    final next = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: next);
    await _engine.setVolume(next);
  }

  void cycleRepeat() {
    queue.cycleRepeat();
    state = state.copyWith(repeat: queue.repeat);
    _scheduleSessionSave(flush: true);
  }

  void toggleShuffle() {
    queue.setShuffle(!queue.shuffle);
    state = state.copyWith(
      shuffle: queue.shuffle,
      queueIds: List<int>.of(queue.ids),
    );
    _scheduleSessionSave(flush: true);
  }

  Future<void> _openCurrent({bool crossfade = false, bool play = true}) async {
    _openCrossfade = crossfade;
    if (_opening) {
      _openAgain = true;
      return;
    }
    _opening = true;
    _holdPosition = true;
    try {
      do {
        _openAgain = false;
        final useCrossfade = _openCrossfade;
        final id = queue.currentId;
        if (id == null) return;
        final track = await _db.trackById(id);
        if (track == null) return;
        _crossfadeArmed = false;
        _clearSeekLock();
        _positionFlush?.cancel();
        _positionFlush = null;
        _queuedPosition = null;
        state = state.copyWith(
          trackId: id,
          title: track.title,
          artist: track.artist,
          album: track.album,
          artworkPath: track.artworkPath,
          clearArtist: track.artist == null,
          clearAlbum: track.album == null,
          clearArtwork: track.artworkPath == null,
          queueIds: List<int>.of(queue.ids),
          repeat: queue.repeat,
          shuffle: queue.shuffle,
          playing: play,
          position: Duration.zero,
          duration: _taggedDuration(track),
        );
        _wantPlaying = play;
        final uri = await _resolvers.resolve(
          TrackLocator(source: track.source, locator: track.locator),
        );
        if (_openAgain) continue;
        if (useCrossfade) {
          await _engine.crossfadeTo(uri);
        } else if (play) {
          await _engine.play(uri);
        } else {
          await _engine.load(uri);
        }
        if (_openAgain) continue;
        await _engine.setVolume(state.volume);
        if (play) {
          _wantPlaying = true;
          state = state.copyWith(playing: true);
          await _engine.resume();
        } else {
          _wantPlaying = false;
          await _engine.pause();
        }
      } while (_openAgain);
    } finally {
      _holdPosition = false;
      _opening = false;
    }
  }

  static Duration _taggedDuration(Track track) {
    final ms = track.durationMs;
    if (ms == null || ms <= 0) return Duration.zero;
    return Duration(milliseconds: ms);
  }

  Future<void> _considerAutoCrossfade(Duration position) async {
    final fade = ref.read(playbackSettingsProvider).crossfade;
    if (fade <= Duration.zero || _crossfadeArmed || _opening) return;
    if (!state.playing) return;
    final total = state.duration;
    if (total <= fade + fade) return;
    final remaining = total - position;
    final nextId = queue.peekNextId();
    if (nextId == null) return;
    if (remaining <= fade + const Duration(seconds: 2)) {
      unawaited(_prefetch(nextId));
    }
    if (remaining <= fade && position > Duration.zero) {
      _crossfadeArmed = true;
      await skipNext();
    }
  }

  Future<void> _prefetch(int id) async {
    final track = await _db.trackById(id);
    if (track == null) return;
    final uri = await _resolvers.resolve(
      TrackLocator(source: track.source, locator: track.locator),
    );
    await _engine.prepare(uri);
  }

  Future<void> _restoreSession() async {
    if (queue.ids.isNotEmpty) return;
    final loaded = _sessionStore.load();
    if (loaded.isEmpty) return;
    _restoring = true;
    try {
      final known = await _db.existingTrackIds(loaded.queueIds);
      final session = loaded.keepKnown(known);
      if (session.isEmpty || queue.ids.isNotEmpty) return;
      queue.shuffle = session.shuffle;
      queue.repeat = session.repeat;
      queue.load(session.queueIds, nextIndex: session.index);
      await _openCurrent(play: false);
      final position = session.position;
      if (position <= Duration.zero) return;
      _armSeek(position);
      state = state.copyWith(position: position);
      await _engine.seek(position);
    } finally {
      _restoring = false;
    }
  }

  void saveSession() {
    _sessionSave?.cancel();
    _sessionSave = null;
    _sessionSavedAt = DateTime.now();
    _sessionStore.save(
      PlaybackSession(
        queueIds: List<int>.of(queue.ids),
        index: queue.index,
        position: state.position,
        repeat: queue.repeat,
        shuffle: queue.shuffle,
      ),
    );
  }

  void _scheduleSessionSave({bool flush = false}) {
    if (_restoring) return;
    if (flush) {
      saveSession();
      return;
    }
    final last = _sessionSavedAt;
    final now = DateTime.now();
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      _sessionSave ??= Timer(const Duration(seconds: 5), saveSession);
      return;
    }
    saveSession();
  }
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackUiState>(
      PlaybackController.new,
    );
