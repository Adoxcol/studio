enum QueueRepeatMode { off, all, one }

class PlaybackQueue {
  PlaybackQueue({
    List<int>? ids,
    this.index = 0,
    this.repeat = QueueRepeatMode.off,
    this.shuffle = false,
  }) : ids = List<int>.of(ids ?? const []);

  List<int> ids;
  int index;
  QueueRepeatMode repeat;
  bool shuffle;

  int? get currentId {
    if (ids.isEmpty || index < 0 || index >= ids.length) return null;
    return ids[index];
  }

  void replace(List<int> nextIds, {int startIndex = 0}) {
    ids = List<int>.of(nextIds);
    if (shuffle) {
      ids.shuffle();
      if (startIndex >= 0 && startIndex < nextIds.length) {
        final startId = nextIds[startIndex];
        ids.remove(startId);
        ids.insert(0, startId);
        index = 0;
        return;
      }
    }
    index = ids.isEmpty ? 0 : startIndex.clamp(0, ids.length - 1);
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
