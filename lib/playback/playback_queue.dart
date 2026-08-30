enum QueueRepeatMode {
  off,
  all,
  one;

  static QueueRepeatMode fromName(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return QueueRepeatMode.off;
  }
}

class PlaybackQueue {
  PlaybackQueue({
    List<int>? ids,
    this.index = 0,
    this.repeat = QueueRepeatMode.off,
    this.shuffle = false,
  })  : ids = List<int>.of(ids ?? const []),
        _source = List<int>.of(ids ?? const []);

  /// Current play order (shuffled when [shuffle] is on).
  List<int> ids;

  /// Original order, restored when shuffle is turned off.
  List<int> _source;
  int index;
  QueueRepeatMode repeat;
  bool shuffle;

  int? get currentId {
    if (ids.isEmpty || index < 0 || index >= ids.length) return null;
    return ids[index];
  }

  /// Next id [moveNext] would select, without changing [index].
  int? peekNextId() {
    if (ids.isEmpty) return null;
    if (repeat == QueueRepeatMode.one) return currentId;
    if (index + 1 < ids.length) return ids[index + 1];
    if (repeat == QueueRepeatMode.all) return ids.first;
    return null;
  }

  void replace(List<int> nextIds, {int startIndex = 0}) {
    _source = List<int>.of(nextIds);
    ids = List<int>.of(nextIds);
    if (shuffle && ids.isNotEmpty) {
      final startId = startIndex >= 0 && startIndex < nextIds.length
          ? nextIds[startIndex]
          : ids.first;
      index = ids.indexOf(startId);
      if (index < 0) index = 0;
      _shuffleKeepingCurrent();
      return;
    }
    index = ids.isEmpty ? 0 : startIndex.clamp(0, ids.length - 1);
  }

  /// Loads a saved play order without reshuffling.
  void load(List<int> nextIds, {required int nextIndex}) {
    _source = List<int>.of(nextIds);
    ids = List<int>.of(nextIds);
    index = ids.isEmpty ? 0 : nextIndex.clamp(0, ids.length - 1);
  }

  /// Turns shuffle on or off. On: current track stays first, the rest is
  /// randomized. Off: original order comes back with the current track kept.
  void setShuffle(bool value) {
    if (shuffle == value) return;
    shuffle = value;
    if (ids.isEmpty) return;
    if (value) {
      if (_source.isEmpty) _source = List<int>.of(ids);
      _shuffleKeepingCurrent();
      return;
    }
    final current = currentId;
    ids = List<int>.of(_source);
    if (current == null || ids.isEmpty) {
      index = 0;
      return;
    }
    final found = ids.indexOf(current);
    index = found < 0 ? 0 : found;
  }

  void _shuffleKeepingCurrent() {
    final i = index.clamp(0, ids.length - 1);
    final current = ids[i];
    final rest = [...ids.sublist(0, i), ...ids.sublist(i + 1)];
    rest.shuffle();
    ids = [current, ...rest];
    index = 0;
  }

  bool moveNext() {
    if (ids.isEmpty) return false;
    if (repeat == QueueRepeatMode.one) return true;
    if (index + 1 < ids.length) {
      index++;
      return true;
    }
    if (repeat == QueueRepeatMode.all) {
      index = 0;
      return true;
    }
    return false;
  }

  bool movePrevious() {
    if (ids.isEmpty) return false;
    if (index > 0) {
      index--;
      return true;
    }
    if (repeat == QueueRepeatMode.all) {
      index = ids.length - 1;
      return true;
    }
    return false;
  }

  void cycleRepeat() {
    repeat = switch (repeat) {
      QueueRepeatMode.off => QueueRepeatMode.all,
      QueueRepeatMode.all => QueueRepeatMode.one,
      QueueRepeatMode.one => QueueRepeatMode.off,
    };
  }
}
