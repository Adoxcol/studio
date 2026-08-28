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

  test('replace with startIndex selects that track', () {
    final queue = PlaybackQueue();
    queue.replace([4, 5, 6], startIndex: 2);
    expect(queue.currentId, 6);
  });
}
