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
    List<int>? historyIds,
    this.index = 0,
    this.repeat = QueueRepeatMode.off,
    this.shuffle = false,
  }) : ids = List<int>.of(ids ?? const []),
       historyIds = List<int>.of(historyIds ?? const []),
       _source = List<int>.of(ids ?? const []);

  static const int historyLimit = 200;

  /// Current play order (shuffled when [shuffle] is on).
  List<int> ids;
  List<int> historyIds;

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
    historyIds.clear();
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

  void loadHistory(List<int> nextHistoryIds) {
    historyIds = List<int>.of(
      nextHistoryIds.length <= historyLimit
          ? nextHistoryIds
          : nextHistoryIds.sublist(nextHistoryIds.length - historyLimit),
    );
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
    if (historyIds.isNotEmpty) {
      final previous = historyIds.removeLast();
      ids.insert(0, previous);
      _source = List<int>.of(ids);
      index = 0;
      return true;
    }
    if (repeat == QueueRepeatMode.all) {
      index = ids.length - 1;
      return true;
    }
    return false;
  }

  /// Drops queue history while keeping the current track and everything after
  /// it in the same play order.
  void discardBeforeCurrent({bool remember = true}) {
    if (ids.isEmpty || index <= 0) return;
    if (remember) _remember(ids.take(index));
    ids = List<int>.of(ids.sublist(index));
    _source = List<int>.of(ids);
    index = 0;
  }

  void _remember(Iterable<int> consumed) {
    historyIds.addAll(consumed);
    if (historyIds.length > historyLimit) {
      historyIds = historyIds.sublist(historyIds.length - historyLimit);
    }
  }

  void playNext(int id) {
    if (ids.isEmpty) {
      ids = [id];
      _source = [id];
      index = 0;
      return;
    }
    final insertionIndex = index + 1;
    final existing = ids.indexOf(id, insertionIndex);
    if (existing >= 0) ids.removeAt(existing);
    ids.insert(insertionIndex.clamp(0, ids.length), id);
    _source = List<int>.of(ids);
  }

  void addToEnd(int id) {
    if (ids.contains(id)) return;
    ids.add(id);
    _source = List<int>.of(ids);
  }

  bool removeUpcomingAt(int queueIndex) {
    if (queueIndex <= index || queueIndex >= ids.length) return false;
    ids.removeAt(queueIndex);
    _source = List<int>.of(ids);
    return true;
  }

  bool insertUpcomingAt(int queueIndex, int id) {
    if (ids.isEmpty) return false;
    final existing = ids.indexOf(id, index + 1);
    if (existing >= 0) ids.removeAt(existing);
    final insertion = queueIndex.clamp(index + 1, ids.length);
    ids.insert(insertion, id);
    _source = List<int>.of(ids);
    return true;
  }

  int removeUpcomingIds(Set<int> removedIds) {
    if (removedIds.isEmpty || ids.isEmpty) return 0;
    var removed = 0;
    for (var queueIndex = ids.length - 1; queueIndex > index; queueIndex--) {
      if (removedIds.contains(ids[queueIndex])) {
        ids.removeAt(queueIndex);
        removed++;
      }
    }
    if (removed > 0) _source = List<int>.of(ids);
    return removed;
  }

  bool moveUpcoming(int oldIndex, int newIndex) {
    if (oldIndex <= index || oldIndex >= ids.length) return false;
    final target = newIndex.clamp(index + 1, ids.length);
    final id = ids.removeAt(oldIndex);
    var insertion = target;
    if (oldIndex < insertion) insertion--;
    ids.insert(insertion.clamp(index + 1, ids.length), id);
    _source = List<int>.of(ids);
    return true;
  }

  void clearUpcoming() {
    if (ids.isEmpty) return;
    ids = [currentId!];
    _source = List<int>.of(ids);
    index = 0;
  }

  void clearHistory() => historyIds.clear();

  bool restoreHistoryAt(int historyIndex) {
    if (historyIndex < 0 || historyIndex >= historyIds.length) return false;
    final restored = historyIds.sublist(historyIndex);
    historyIds = List<int>.of(historyIds.take(historyIndex));
    ids = [...restored, ...ids];
    _source = List<int>.of(ids);
    index = 0;
    return true;
  }

  void cycleRepeat() {
    repeat = switch (repeat) {
      QueueRepeatMode.off => QueueRepeatMode.all,
      QueueRepeatMode.all => QueueRepeatMode.one,
      QueueRepeatMode.one => QueueRepeatMode.off,
    };
  }
}
