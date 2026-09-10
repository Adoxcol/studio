import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/artwork_hue.dart';

void main() {
  test('hue cache is bounded LRU and reuses repeated artwork', () async {
    final calls = <String>[];
    final cache = ArtworkHueCache(
      capacity: 2,
      loader: (path) async {
        calls.add(path);
        return 20;
      },
    );
    addTearDown(cache.dispose);
    for (final path in ['a', 'b', 'a', 'c', 'a', 'b']) {
      expect(await cache.read(path), 20);
    }
    expect(calls, ['a', 'b', 'c', 'b']);
  });

  test('rapid skips decode only active and latest pending artwork', () async {
    final gate = Completer<double?>();
    final calls = <String>[];
    final cache = ArtworkHueCache(
      loader: (path) {
        calls.add(path);
        return path == 'a' ? gate.future : Future.value(30);
      },
    );
    addTearDown(cache.dispose);
    final a = cache.read('a');
    expect(cache.read('a'), same(a));
    final b = cache.read('b');
    final c = cache.read('c');
    expect(await b, isNull);
    gate.complete(10);
    expect(await a, 10);
    expect(await c, 30);
    expect(calls, ['a', 'c']);
  });

  test('failed extraction retries and disposal abandons queued work', () async {
    var calls = 0;
    final cache = ArtworkHueCache(
      loader: (_) async {
        if (++calls == 1) throw StateError('unavailable');
        return 42;
      },
    );
    expect(await cache.read('a'), isNull);
    expect(await cache.read('a'), 42);
    cache.dispose();
    expect(await cache.read('b'), isNull);
    expect(calls, 2);
  });
}
