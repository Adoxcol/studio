import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/crossfade.dart';

void main() {
  test('equal-power endpoints and midpoint', () {
    final start = Crossfade.gains(0);
    expect(start.outgoing, closeTo(1, 0.0001));
    expect(start.incoming, closeTo(0, 0.0001));

    final end = Crossfade.gains(1);
    expect(end.outgoing, closeTo(0, 0.0001));
    expect(end.incoming, closeTo(1, 0.0001));

    final mid = Crossfade.gains(0.5);
    expect(mid.outgoing, closeTo(math.sqrt1_2, 0.0001));
    expect(mid.incoming, closeTo(math.sqrt1_2, 0.0001));
  });

  group('headroom-safe overlap gains', () {
    test('preserve the equal-power endpoints', () {
      final start = Crossfade.headroomSafeGains(0);
      final end = Crossfade.headroomSafeGains(1);

      expect(start.outgoing, 1);
      expect(start.incoming, 0);
      expect(end.outgoing, 0);
      expect(end.incoming, 1);
    });

    test('keep the midpoint linear sum within unity', () {
      final midpoint = Crossfade.headroomSafeGains(0.5);

      expect(midpoint.outgoing, closeTo(0.5, 1e-12));
      expect(midpoint.incoming, closeTo(0.5, 1e-12));
      expect(midpoint.outgoing + midpoint.incoming, lessThanOrEqualTo(1));
    });

    test('are symmetric around the midpoint', () {
      final early = Crossfade.headroomSafeGains(0.25);
      final late = Crossfade.headroomSafeGains(0.75);

      expect(early.outgoing, closeTo(late.incoming, 1e-12));
      expect(early.incoming, closeTo(late.outgoing, 1e-12));
    });

    test('remain finite and clamped for invalid or out-of-range progress', () {
      final inputs = <double>[
        double.negativeInfinity,
        -1,
        double.nan,
        0,
        0.5,
        1,
        2,
        double.infinity,
      ];

      for (final input in inputs) {
        final gains = Crossfade.headroomSafeGains(input);

        expect(gains.outgoing.isFinite, isTrue, reason: 'outgoing for $input');
        expect(gains.incoming.isFinite, isTrue, reason: 'incoming for $input');
        expect(
          gains.outgoing,
          inInclusiveRange(0.0, 1.0),
          reason: 'outgoing for $input',
        );
        expect(
          gains.incoming,
          inInclusiveRange(0.0, 1.0),
          reason: 'incoming for $input',
        );
        expect(
          gains.outgoing + gains.incoming,
          lessThanOrEqualTo(1.0 + 1e-12),
          reason: 'linear sum for $input',
        );
      }

      expect(Crossfade.headroomSafeGains(-1), Crossfade.headroomSafeGains(0));
      expect(Crossfade.headroomSafeGains(2), Crossfade.headroomSafeGains(1));
      expect(
        Crossfade.headroomSafeGains(double.nan),
        Crossfade.headroomSafeGains(0),
      );
    });
  });

  test('labels and stored durations', () {
    expect(Crossfade.label(Duration.zero), 'Off');
    expect(Crossfade.label(Crossfade.fiveSeconds), '5s');
    expect(Crossfade.fromMilliseconds(5000), Crossfade.fiveSeconds);
    expect(Crossfade.fromMilliseconds(null), Duration.zero);
    expect(Crossfade.fromMilliseconds(20000).inSeconds, Crossfade.maxSeconds);
    expect(Crossfade.fromSeconds(7), const Duration(seconds: 7));
    expect(Crossfade.fromSeconds(15), Crossfade.max);
    expect(Crossfade.fromSeconds(0), Crossfade.off);
    expect(Crossfade.label(Crossfade.max), '15s');
  });
}
