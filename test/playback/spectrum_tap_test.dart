import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/spectrum_tap.dart';

void main() {
  test('FFT tap never falls back to a real audio device', () {
    expect(MpvSpectrumTap.audioOutput, 'pcm,null');
    expect(MpvSpectrumTap.audioOutput.contains('wasapi'), isFalse);
    expect(MpvSpectrumTap.audioOutput.contains('pulse'), isFalse);
    expect(MpvSpectrumTap.audioOutput.contains('coreaudio'), isFalse);
  });
}
