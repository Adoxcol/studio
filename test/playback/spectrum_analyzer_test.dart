import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/spectrum_analyzer.dart';
import 'package:studio/ui/visualizer/spectrum_visualizer.dart';

Uint8List _sineFloat32({
  required double hz,
  required int sampleRate,
  required int frames,
  int channels = 2,
}) {
  final bytes = ByteData(frames * channels * 4);
  for (var i = 0; i < frames; i++) {
    final sample = math.sin(2 * math.pi * hz * i / sampleRate);
    for (var ch = 0; ch < channels; ch++) {
      bytes.setFloat32((i * channels + ch) * 4, sample, Endian.little);
    }
  }
  return bytes.buffer.asUint8List();
}

void main() {
  test('idle bars stay low', () {
    expect(idleLevel(3), lessThan(0.25));
    expect(idleLevel(3), greaterThan(0.05));
  });

  test('a 1 kHz sine peaks near the 1 kHz band', () {
    final analyzer = SpectrumAnalyzer(sampleRate: 48000, attack: 1, release: 1);
    List<double>? bands;
    final pcm = _sineFloat32(hz: 1000, sampleRate: 48000, frames: 4096);
    var offset = 0;
    while (offset < pcm.length) {
      final end = math.min(offset + 2048, pcm.length);
      bands =
          analyzer.addInterleavedFloat32(
            Uint8List.sublistView(pcm, offset, end),
          ) ??
          bands;
      offset = end;
    }
    expect(bands, isNotNull);
    final peak = bands!.indexOf(bands.reduce(math.max));
    expect((peak - analyzer.bandIndexForHz(1000)).abs(), lessThanOrEqualTo(1));
    expect(bands[peak], greaterThan(0.4));
  });

  test('silence stays near zero', () {
    final analyzer = SpectrumAnalyzer(attack: 1, release: 1);
    final pcm = Uint8List(2048 * 2 * 4);
    analyzer.addInterleavedFloat32(pcm);
    final bands = analyzer.addInterleavedFloat32(pcm);
    expect(bands, isNotNull);
    for (final band in bands!) {
      expect(band, lessThan(0.05));
    }
  });
}
