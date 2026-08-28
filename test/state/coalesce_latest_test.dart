import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/state/library_providers.dart';

void main() {
  test(
    'coalesceLatest emits first value immediately and trailing latest',
    () async {
      final source = StreamController<int>();
      final seen = <int>[];
      final sub = coalesceLatest(
        source.stream,
        const Duration(milliseconds: 40),
      ).listen(seen.add);
      addTearDown(() async {
        await sub.cancel();
        await source.close();
      });

      source.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1]);

      source.add(2);
      source.add(3);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(seen, [1, 3]);
    },
  );
}
