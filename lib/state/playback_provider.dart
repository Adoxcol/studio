import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/providers/resolver_registry.dart';
import 'package:studio/state/library_providers.dart';

@immutable
class PlaybackUiState {
  const PlaybackUiState({
    this.trackId,
    this.title = 'Not playing',
    this.artist,
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
  final bool playing;
  final Duration position;
  final Duration duration;
  final double volume;
  final QueueRepeatMode repeat;
  final bool shuffle;
  final List<int> queueIds;

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  PlaybackUiState copyWith({
    int? trackId,
    String? title,
    String? artist,
    bool? playing,
    Duration? position,
    Duration? duration,
    double? volume,
    QueueRepeatMode? repeat,
    bool? shuffle,
    List<int>? queueIds,
    bool clearArtist = false,
  }) {
    return PlaybackUiState(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: clearArtist ? null : artist ?? this.artist,
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
  final queue = PlaybackQueue();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  PlaybackUiState build() {
    _engine = ref.watch(audioEngineProvider);
    _db = ref.watch(studioDatabaseProvider);
    _resolvers = ref.watch(resolverRegistryProvider);

    _subs.add(
      _engine.position.listen((value) {
        state = state.copyWith(position: value);
      }),
    );
    _subs.add(
      _engine.duration.listen((value) {
        state = state.copyWith(duration: value);
      }),
    );
    _subs.add(
      _engine.playing.listen((value) {
        state = state.copyWith(playing: value);
      }),
    );
    _subs.add(
      _engine.completed.listen((_) {
        unawaited(skipNext());
      }),
    );

    ref.onDispose(() {
      for (final sub in _subs) {
        unawaited(sub.cancel());
      }
    });

    return const PlaybackUiState();
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
  }

  Future<void> togglePlayPause() async {
    if (state.trackId == null) return;
    if (state.playing) {
      await _engine.pause();
    } else {
      await _engine.resume();
    }
  }

  Future<void> skipNext() async {
    if (!queue.moveNext()) return;
    await _openCurrent();
  }

  Future<void> skipPrevious() async {
    if (state.position > const Duration(seconds: 3)) {
      await _engine.seek(Duration.zero);
      return;
    }
    if (!queue.movePrevious()) return;
    await _openCurrent();
  }

  Future<void> seekFraction(double fraction) async {
    final total = state.duration;
    if (total <= Duration.zero) return;
    await _engine.seek(total * fraction.clamp(0.0, 1.0));
  }

  Future<void> setVolume(double volume) async {
    final next = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: next);
    await _engine.setVolume(next);
  }

  void cycleRepeat() {
    queue.cycleRepeat();
    state = state.copyWith(repeat: queue.repeat);
  }

  void toggleShuffle() {
    queue.shuffle = !queue.shuffle;
    state = state.copyWith(shuffle: queue.shuffle);
  }

  Future<void> _openCurrent() async {
    final id = queue.currentId;
    if (id == null) return;
    final track = await _db.trackById(id);
    if (track == null) return;
    final uri = await _resolvers.resolve(
      TrackLocator(source: track.source, locator: track.locator),
    );
    await _engine.play(uri);
    await _engine.setVolume(state.volume);
    state = state.copyWith(
      trackId: id,
      title: track.title,
      artist: track.artist,
      clearArtist: track.artist == null,
      queueIds: List<int>.of(queue.ids),
      repeat: queue.repeat,
      shuffle: queue.shuffle,
      position: Duration.zero,
    );
  }
}

final playbackControllerProvider =
    NotifierProvider<PlaybackController, PlaybackUiState>(
      PlaybackController.new,
    );
