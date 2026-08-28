import 'package:studio/playback/playback_queue.dart';

/// Queue, current track, and playhead to restore after Quit.
class PlaybackSession {
  const PlaybackSession({
    this.queueIds = const [],
    this.index = 0,
    this.position = Duration.zero,
    this.repeat = QueueRepeatMode.off,
    this.shuffle = false,
  });

  static const empty = PlaybackSession();

  final List<int> queueIds;
  final int index;
  final Duration position;
  final QueueRepeatMode repeat;
  final bool shuffle;

  bool get isEmpty => queueIds.isEmpty;

  int? get currentId {
    if (queueIds.isEmpty || index < 0 || index >= queueIds.length) return null;
    return queueIds[index];
  }

  /// Drops ids that are no longer in the library and keeps the same track
  /// if it survived.
  PlaybackSession keepKnown(Set<int> knownIds) {
    final kept = [
      for (final id in queueIds)
        if (knownIds.contains(id)) id,
    ];
    if (kept.isEmpty) return empty;
    final current = currentId;
    var nextIndex = current == null ? 0 : kept.indexOf(current);
    if (nextIndex < 0) nextIndex = 0;
    return PlaybackSession(
      queueIds: kept,
      index: nextIndex,
      position: current != null && kept.contains(current)
          ? position
          : Duration.zero,
      repeat: repeat,
      shuffle: shuffle,
    );
  }

  Map<String, Object?> toJson() => {
    'queueIds': queueIds,
    'index': index,
    'positionMs': position.inMilliseconds,
    'repeat': repeat.name,
    'shuffle': shuffle,
  };

  static PlaybackSession fromJson(Map<String, dynamic> json) {
    final rawIds = json['queueIds'];
    final ids = rawIds is List
        ? [for (final value in rawIds) (value as num).toInt()]
        : const <int>[];
    final rawIndex = json['index'];
    final index = rawIndex is num ? rawIndex.toInt() : 0;
    final rawMs = json['positionMs'];
    final ms = rawMs is num ? rawMs.toInt() : 0;
    return PlaybackSession(
      queueIds: ids,
      index: ids.isEmpty ? 0 : index.clamp(0, ids.length - 1),
      position: Duration(milliseconds: ms < 0 ? 0 : ms),
      repeat: QueueRepeatMode.fromName(json['repeat'] as String?),
      shuffle: json['shuffle'] == true,
    );
  }
}
