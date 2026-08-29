import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/equalizer_import.dart';

void main() {
  test('GraphicEQ interpolates onto ISO 10-band centers', () {
    const text = '''
Preamp: -6.2 dB
GraphicEQ: 25 0; 31.5 4; 63 4; 125 0; 250 0; 500 0; 1000 0; 2000 0; 4000 0; 8000 -2; 16000 -2
''';
    final imported = EqualizerImport.parse(text);
    expect(imported.preamp, closeTo(-6.2, 0.01));
    expect(imported.gains, hasLength(10));
    expect(imported.gains[0], closeTo(4, 0.05));
    expect(imported.gains[1], closeTo(4, 0.05));
    expect(imported.gains[2], closeTo(0, 0.05));
    expect(imported.gains[8], closeTo(-2, 0.05));
  });

  test('GraphicEQ log-interpolates a point between two nodes', () {
    const text = 'GraphicEQ: 31.5 0; 125 6';
    final imported = EqualizerImport.parse(text);
    expect(imported.gains[1], closeTo(3, 0.3));
  });

  test('parametric AutoEQ Filter lines sample onto 10 bands', () {
    const text = '''
Preamp: -5.4 dB
Filter 1: ON PK Fc 1000 Hz Gain 6.0 dB Q 1.41
''';
    final imported = EqualizerImport.parse(text);
    expect(imported.preamp, closeTo(-5.4, 0.01));
    expect(imported.gains[5], closeTo(6, 1.0));
    expect(imported.gains.first.abs(), lessThan(2));
  });

  test('JSON 10-gain dump round-trips', () {
    final imported = EqualizerImport.parse(
      '{"preamp": -3, "gains": [1, 2, 3, 4, 5, 0, 0, 0, 0, 0]}',
    );
    expect(imported.preamp, -3);
    expect(imported.gains.first, 1);
    expect(imported.gains[4], 5);
  });

  test('bare JSON array is 10 gains', () {
    final imported = EqualizerImport.parse('[0, 0, 0, 0, 0, 1, 2, 3, 4, 5]');
    expect(imported.preamp, 0);
    expect(imported.gains.last, 5);
  });

  test('whitespace-separated 10-band dump', () {
    final imported = EqualizerImport.parse('0 1 2 3 4 5 4 3 2 1');
    expect(
      imported.gains,
      Equalizer.clampGains([0, 1, 2, 3, 4, 5, 4, 3, 2, 1]),
    );
  });

  test('gains past the slider range are clamped', () {
    final imported = EqualizerImport.parse(
      '{"gains": [40, 0, 0, 0, 0, 0, 0, 0, 0, -40]}',
    );
    expect(imported.gains.first, Equalizer.maxGain);
    expect(imported.gains.last, Equalizer.minGain);
  });

  test('unknown text is rejected', () {
    expect(
      () => EqualizerImport.parse('not an equalizer'),
      throwsFormatException,
    );
  });
}
