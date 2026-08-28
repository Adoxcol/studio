import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  test('graphic EQ is not sent to mpv (bundled libmpv has no lavfi EQ)', () {
    expect(Equalizer.afFilter(Equalizer.flat), isEmpty);
    expect(Equalizer.afFilter(Equalizer.warm), isEmpty);
    expect(Equalizer.afFilter(Equalizer.bright), isEmpty);
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
