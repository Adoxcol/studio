import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/watch_coalesced_query.dart';

void main() {
  test('bursts execute one trailing query, not one query per write', () async {
    final changes = StreamController<void>();
    var queries = 0;
    var version = 0;
    final initial = Completer<void>();
    final trailing = Completer<void>();
    final values = <int>[];
    final sub =
        watchCoalescedQuery(changes.stream, () async {
          queries++;
          return version;
        }, window: const Duration(milliseconds: 50)).listen((value) {
          values.add(value);
          if (value == 0) initial.complete();
          if (value == 100) trailing.complete();
        });
    await initial.future;
    for (var i = 0; i < 100; i++) {
      version++;
      changes.add(null);
    }
    await trailing.future.timeout(const Duration(seconds: 5));
    expect(values, [0, 100]);
    expect(queries, 2);
    await sub.cancel();
    await changes.close();
  });

  test('slow queries never overlap or lose updates during a query', () async {
    final changes = StreamController<void>();
    final pending = <Completer<int>>[];
    final startedSecond = Completer<void>();
    final receivedSecond = Completer<void>();
    final values = <int>[];
    final sub =
        watchCoalescedQuery(changes.stream, () {
          final result = Completer<int>();
          pending.add(result);
          if (pending.length == 2) startedSecond.complete();
          return result.future;
        }, window: const Duration(milliseconds: 10)).listen((value) {
          values.add(value);
          if (value == 2) receivedSecond.complete();
        });
    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(pending.length, 1);
    pending[0].complete(1);
    await startedSecond.future.timeout(const Duration(seconds: 5));
    pending[1].complete(2);
    await receivedSecond.future;
    expect(values, [1, 2]);
    await sub.cancel();
    await changes.close();
  });

  test('errors remain retryable and cancellation drops late results', () async {
    final changes = StreamController<void>();
    final pending = <Completer<int>>[];
    final failed = Completer<void>();
    final startedSecond = Completer<void>();
    final values = <int>[];
    final sub = watchCoalescedQuery(
      changes.stream,
      () {
        final result = Completer<int>();
        pending.add(result);
        if (pending.length == 2) startedSecond.complete();
        return result.future;
      },
      window: const Duration(milliseconds: 10),
    ).listen(values.add, onError: (Object error) => failed.complete());
    pending[0].completeError(StateError('temporary failure'));
    await failed.future;
    changes.add(null);
    await startedSecond.future.timeout(const Duration(seconds: 5));
    await sub.cancel();
    pending[1].complete(42);
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    expect(changes.hasListener, isFalse);
    await changes.close();
  });

  test('source completion flushes pending refresh and closes', () async {
    final changes = StreamController<void>();
    var version = 0;
    final initial = Completer<void>();
    final values = <int>[];
    final done = Completer<void>();
    watchCoalescedQuery(
      changes.stream,
      () async => version,
      window: const Duration(milliseconds: 10),
    ).listen((value) {
      values.add(value);
      if (value == 0) initial.complete();
    }, onDone: done.complete);
    await initial.future;
    version = 1;
    changes.add(null);
    await changes.close();
    await done.future.timeout(const Duration(seconds: 5));
    expect(values, [0, 1]);
  });
}
