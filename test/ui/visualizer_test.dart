import 'package:flutter_test/flutter_test.dart';
import 'package:studio/ui/visualizer/amplitude_visualizer.dart';

void main() {
  test('idle bars stay low and playing bars can reach the top', () {
    const position = Duration(milliseconds: 1250);
    final idle = amplitudeAt(index: 3, position: position, playing: false);
    final live = amplitudeAt(index: 3, position: position, playing: true);
    expect(idle, lessThan(0.25));
    expect(live, greaterThan(idle));
    expect(live, inInclusiveRange(0.08, 1.0));
  });

  test('envelope changes with playback position', () {
    final a = amplitudeAt(index: 8, position: Duration.zero, playing: true);
    final b = amplitudeAt(
      index: 8,
      position: const Duration(milliseconds: 400),
      playing: true,
    );
    expect(a, isNot(b));
  });
}
