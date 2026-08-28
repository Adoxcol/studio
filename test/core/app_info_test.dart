import 'package:flutter_test/flutter_test.dart';
import 'package:studio/core/app_info.dart';

void main() {
  test('app display name and version identify the LRCLIB client', () {
    expect(kAppName, 'Studio');
    expect(kAppVersion, '0.1.0');
    expect(kAppHomepage, contains('github.com/Adoxcol/studio'));
  });
}
