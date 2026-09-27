import 'package:flutter_test/flutter_test.dart';
import 'package:studio/core/byte_format.dart';

void main() {
  test('formats sizes with binary units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1023), '1023 B');
    expect(formatBytes(1536), '2 KB');
    expect(formatBytes(5 * 1024 * 1024 + 300 * 1024), '5.3 MB');
    expect(formatBytes(150 * 1024 * 1024), '150 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
  });
}
