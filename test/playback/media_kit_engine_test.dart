import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/media_kit_engine.dart';

void main() {
  test('only expected mpv compatibility noise is suppressed', () {
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
    expect(
      isBenignMpvLog(
        prefix: 'ffmpeg',
        text: "'aresample' filter not present, cannot convert formats.",
      ),
      isFalse,
    );
    expect(
      isBenignMpvLog(prefix: 'ffmpeg', text: "No such filter: 'equalizer'"),
      isFalse,
    );
  });
}
