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

  test('labels and presets', () {
    expect(Crossfade.label(Duration.zero), 'Off');
    expect(Crossfade.label(Crossfade.fiveSeconds), '5s');
    expect(Crossfade.fromMilliseconds(5000), Crossfade.fiveSeconds);
    expect(Crossfade.fromMilliseconds(null), Duration.zero);
  });
}
