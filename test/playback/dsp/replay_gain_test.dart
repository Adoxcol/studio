import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

void main() {
  group('ReplayGainMode', () {
    test('fromName returns correct mode for valid names', () {
      expect(ReplayGainMode.fromName('off'), ReplayGainMode.off);
      expect(ReplayGainMode.fromName('track'), ReplayGainMode.track);
      expect(ReplayGainMode.fromName('album'), ReplayGainMode.album);
    });

    test('fromName returns off for invalid names', () {
      expect(ReplayGainMode.fromName('invalid'), ReplayGainMode.off);
      expect(ReplayGainMode.fromName(''), ReplayGainMode.off);
    });

    test('fromName returns off for null', () {
      expect(ReplayGainMode.fromName(null), ReplayGainMode.off);
    });

    test('verify label values', () {
      expect(ReplayGainMode.off.label, 'Off');
      expect(ReplayGainMode.track.label, 'Track');
      expect(ReplayGainMode.album.label, 'Album');
    });

    test('verify mpv values', () {
      expect(ReplayGainMode.off.mpvValue, 'no');
      expect(ReplayGainMode.track.mpvValue, 'track');
      expect(ReplayGainMode.album.mpvValue, 'album');
    });
  });
}
