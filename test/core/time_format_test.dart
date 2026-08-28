import 'package:flutter_test/flutter_test.dart';
import 'package:studio/core/time_format.dart';

void main() {
  test('formats minutes and seconds without padding the minute', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 58)), '3:58');
    expect(formatDurationMs(238000), '3:58');
  });

  test('formats hours when needed', () {
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('blank duration stays empty', () {
    expect(formatDurationMs(null), '');
    expect(formatDurationMs(-1), '');
  });
}
