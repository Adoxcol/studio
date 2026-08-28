import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  test('flat curve disables the mpv filter', () {
    expect(Equalizer.afFilter(Equalizer.flat), isEmpty);
  });

  test('warm curve builds a lavfi firequalizer graph', () {
    final af = Equalizer.afFilter(Equalizer.warm);
    expect(af, startsWith('lavfi=[firequalizer=gain_entry=\''));
    expect(af, contains('entry(60,3.0)'));
    expect(af, contains('entry(16000,-2.0)'));
  });

  test('preset lookup falls back to flat', () {
    expect(EqualizerPreset.fromName('bright'), EqualizerPreset.bright);
    expect(EqualizerPreset.fromName('nope'), EqualizerPreset.flat);
  });

  test('file store round-trips a warm curve', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-eq').path}/playback.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FilePlaybackSettingsStore(file).save(
      const PlaybackSettings(
        equalizerPreset: EqualizerPreset.warm,
        equalizerGains: Equalizer.warm,
      ),
    );
    final loaded = FilePlaybackSettingsStore(file).load();
    expect(loaded.equalizerPreset, EqualizerPreset.warm);
    expect(loaded.equalizerGains, Equalizer.warm);
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
  });
}
