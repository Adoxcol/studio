import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/playback_queue.dart';

void main() {
  test('moveNext advances and wrap-around depends on repeat', () {
    final queue = PlaybackQueue(ids: [1, 2, 3]);
    expect(queue.currentId, 1);
    expect(queue.moveNext(), isTrue);
    expect(queue.currentId, 2);
    expect(queue.moveNext(), isTrue);
    expect(queue.currentId, 3);
    expect(queue.moveNext(), isFalse);

    queue.repeat = QueueRepeatMode.all;
    expect(queue.moveNext(), isTrue);
    expect(queue.currentId, 1);
  });

  test('repeat one stays on the same track', () {
    final queue = PlaybackQueue(ids: [10, 20], repeat: QueueRepeatMode.one);
    expect(queue.moveNext(), isTrue);
    expect(queue.currentId, 10);
  });

  test('peekNextId looks ahead without moving', () {
    final queue = PlaybackQueue(ids: [1, 2, 3]);
    expect(queue.peekNextId(), 2);
    expect(queue.currentId, 1);
    queue.index = 2;
    expect(queue.peekNextId(), equals(null));
    queue.repeat = QueueRepeatMode.all;
    expect(queue.peekNextId(), 1);
    queue.repeat = QueueRepeatMode.one;
    expect(queue.peekNextId(), 3);
  });

  test('replace with startIndex selects that track', () {
    final queue = PlaybackQueue();
    queue.replace([4, 5, 6], startIndex: 2);
    expect(queue.currentId, 6);
  });

  test('setShuffle keeps the current track first and restores order', () {
    final queue = PlaybackQueue(ids: [1, 2, 3, 4], index: 1);
    queue.setShuffle(true);
    expect(queue.shuffle, isTrue);
    expect(queue.currentId, 2);
    expect(queue.index, 0);
    expect(queue.ids.toSet(), {1, 2, 3, 4});
    expect(queue.ids.first, 2);

    queue.setShuffle(false);
    expect(queue.shuffle, isFalse);
    expect(queue.ids, [1, 2, 3, 4]);
    expect(queue.currentId, 2);
    expect(queue.index, 1);
  });

  test('replace while shuffle is on keeps the start track first', () {
    final queue = PlaybackQueue(shuffle: true);
    queue.replace([10, 20, 30, 40], startIndex: 2);
    expect(queue.currentId, 30);
    expect(queue.index, 0);
    expect(queue.ids.toSet(), {10, 20, 30, 40});
  });

  test('discardBeforeCurrent keeps the current track and remaining order', () {
    final queue = PlaybackQueue(ids: [1, 2, 3, 4], index: 2);
    queue.discardBeforeCurrent();
    expect(queue.ids, [3, 4]);
    expect(queue.index, 0);
    expect(queue.currentId, 3);
  });
}
