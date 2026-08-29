import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  test('flat curve keeps the supported realtime graph installed', () {
    final af = Equalizer.afFilter(Equalizer.flat);
    expect(af, startsWith('@studio_format:format=format=floatp:srate=48000,'));
    expect(af, contains('@studio_eq:lavfi=['));
    expect(RegExp('equalizer@studio_band_').allMatches(af), hasLength(10));
    expect(af, contains('precision=f32'));
    expect(af, isNot(contains('firequalizer')));
    expect(af, isNot(contains('aresample')));
  });

  test('boosted bands initialize named one-octave biquads', () {
    final af = Equalizer.afFilter(Equalizer.bass);
    expect(
      af,
      contains(
        'equalizer@studio_band_0=frequency=31.5:'
        'width_type=o:width=1.0:gain=6.00:precision=f32',
      ),
    );
    expect(
      af,
      contains(
        'equalizer@studio_band_1=frequency=63.0:'
        'width_type=o:width=1.0:gain=5.00:precision=f32',
      ),
    );
  });

  test('preamp conversion remains independent from filter coefficients', () {
    expect(Equalizer.preampLinear(-6), closeTo(0.5012, 0.001));
    expect(Equalizer.preampLinear(6), closeTo(1.9953, 0.001));
  });

  test('runtime update targets one named band', () {
    final command = Equalizer.afCommand(6, 3);
    expect(command, hasLength(5));
    expect(command, [
      'af-command',
      'studio_eq',
      'gain',
      '3.00',
      'equalizer@studio_band_6',
    ]);
  });

  test('runtime update emits only bands that changed', () {
    final next = List<double>.from(Equalizer.flat)..[4] = 2.5;
    final commands = Equalizer.afCommands(Equalizer.flat, next);
    expect(commands, hasLength(1));
    expect(commands.single.last, 'equalizer@studio_band_4');
    expect(Equalizer.afCommands(null, next), hasLength(10));
  });

  test('runtime update never loses a representable small change', () {
    final previous = List<double>.from(Equalizer.flat)..[4] = 2.50;
    final next = List<double>.from(previous)..[4] = 2.51;

    expect(Equalizer.afCommands(previous, next), [
      ['af-command', 'studio_eq', 'gain', '2.51', 'equalizer@studio_band_4'],
    ]);
  });

  test('runtime update reduces bands before applying boosts', () {
    final previous = List<double>.from(Equalizer.flat)
      ..[1] = 6
      ..[7] = -4;
    final next = List<double>.from(Equalizer.flat)
      ..[1] = -3
      ..[7] = 5;

    final commands = Equalizer.afCommands(previous, next);
    expect(commands.map((command) => command.last), [
      'equalizer@studio_band_1',
      'equalizer@studio_band_7',
    ]);
  });

  test('peak response supplies automatic clipping headroom', () {
    expect(Equalizer.peakGainDb(Equalizer.flat), 0);
    expect(Equalizer.peakGainDb(List<double>.filled(10, -6)), 0);
    expect(Equalizer.peakGainDb(Equalizer.bass), greaterThan(6));
    expect(Equalizer.peakGainDb(Equalizer.bass), lessThan(15));
  });

  test('transition headroom covers both endpoint curves', () {
    final transition = Equalizer.transitionPeakGainDb(
      Equalizer.bass,
      Equalizer.treble,
    );

    expect(
      transition,
      greaterThanOrEqualTo(Equalizer.peakGainDb(Equalizer.bass)),
    );
    expect(
      transition,
      greaterThanOrEqualTo(Equalizer.peakGainDb(Equalizer.treble)),
    );
  });

  test('invalid curves use ten clamped flat points', () {
    expect(Equalizer.normalizeGains(const [99]), Equalizer.flat);
    expect(
      Equalizer.normalizeGains(List<double>.filled(10, 99)),
      List<double>.filled(10, 15),
    );
    expect(() => Equalizer.afCommand(10, 0), throwsRangeError);
  });

  test('preset lookup falls back to flat', () {
    expect(EqualizerPreset.fromName('rock'), EqualizerPreset.rock);
    expect(EqualizerPreset.fromName('warm'), EqualizerPreset.flat);
    expect(EqualizerPreset.fromName('nope'), EqualizerPreset.flat);
  });

  test('file store round-trips a rock curve and preamp', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-eq').path}/playback.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FilePlaybackSettingsStore(file).save(
      PlaybackSettings(
        equalizerPreset: EqualizerPreset.custom,
        equalizerGains: Equalizer.rock,
        equalizerPreamp: -3,
      ),
    );
    final loaded = FilePlaybackSettingsStore(file).load();
    expect(loaded.equalizerPreset, EqualizerPreset.custom);
    expect(loaded.equalizerGains, Equalizer.rock);
    expect(loaded.equalizerPreamp, -3);
  });

  test('file store keeps ReplayGain when equalizer keys are missing', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-eq-legacy').path}/playback.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    file.writeAsStringSync('{"replayGain":"album"}');
    final loaded = FilePlaybackSettingsStore(file).load();
    expect(loaded.replayGain, ReplayGainMode.album);
    expect(loaded.equalizerPreset, EqualizerPreset.flat);
    expect(loaded.equalizerGains, Equalizer.flat);
    expect(loaded.equalizerPreamp, 0);
  });

  test('8-band equalizerGains fall back to flat', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-eq-8').path}/playback.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    file.writeAsStringSync(
      '{"equalizerPreset":"custom","equalizerGains":[3,2,1,0,0,-1,-2,-2]}',
    );
    final loaded = FilePlaybackSettingsStore(file).load();
    expect(loaded.equalizerPreset, EqualizerPreset.flat);
    expect(loaded.equalizerGains, Equalizer.flat);
  });

  test('file store round-trips a 5s crossfade', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-xfade').path}/playback.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FilePlaybackSettingsStore(
      file,
    ).save(const PlaybackSettings(crossfade: Crossfade.fiveSeconds));
    expect(
      FilePlaybackSettingsStore(file).load().crossfade,
      Crossfade.fiveSeconds,
    );
  });
}
