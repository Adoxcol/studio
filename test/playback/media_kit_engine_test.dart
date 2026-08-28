import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/media_kit_engine.dart';

void main() {
  test('OSC missing and disk-cache failures are not printed', () {
    expect(
      isBenignMpvLog(
        prefix: 'media_kit',
        text: 'error: property not found _setProperty(osc, 1)',
      ),
      isTrue,
    );
    expect(
      isBenignMpvLog(prefix: 'lavf', text: 'Failed to create file cache.'),
      isTrue,
    );
    expect(
      isBenignMpvLog(prefix: 'mf', text: 'Failed to create file cache.'),
      isTrue,
    );
    expect(
      isBenignMpvLog(prefix: 'cplayer', text: 'Opening file failed'),
      isFalse,
    );
  });
}
