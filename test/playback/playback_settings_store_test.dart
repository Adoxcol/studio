import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  group('MemoryPlaybackSettingsStore', () {
    test('loads default settings initially', () {
      final store = MemoryPlaybackSettingsStore();
      final settings = store.load();
      expect(settings.replayGain, ReplayGainMode.off);
      expect(settings.equalizerPreset, EqualizerPreset.flat);
      expect(settings.equalizerGains, Equalizer.flat);
      expect(settings.equalizerPreamp, 0.0);
      expect(settings.crossfade, Crossfade.off);
    });

    test('saves and loads new settings', () {
      final store = MemoryPlaybackSettingsStore();
      const newSettings = PlaybackSettings(
        replayGain: ReplayGainMode.album,
        equalizerPreset: EqualizerPreset.rock,
        equalizerPreamp: -3.0,
        crossfade: Crossfade.fiveSeconds,
      );

      store.save(newSettings);
      final loadedSettings = store.load();

      expect(loadedSettings.replayGain, ReplayGainMode.album);
      expect(loadedSettings.equalizerPreset, EqualizerPreset.rock);
      expect(loadedSettings.equalizerPreamp, -3.0);
      expect(loadedSettings.crossfade, Crossfade.fiveSeconds);
    });

    test('can be initialized with custom settings', () {
      const customSettings = PlaybackSettings(
        equalizerPreset: EqualizerPreset.bass,
      );
      final store = MemoryPlaybackSettingsStore(customSettings);

      expect(store.load().equalizerPreset, EqualizerPreset.bass);
    });
  });

  group('FilePlaybackSettingsStore', () {
    late File file;
    late FilePlaybackSettingsStore store;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('studio_settings_test');
      file = File('${dir.path}/playback.json');
      store = FilePlaybackSettingsStore(file);
    });

    tearDown(() {
      if (file.parent.existsSync()) {
        file.parent.deleteSync(recursive: true);
      }
    });

    test('loads default settings when file does not exist', () {
      final settings = store.load();
      expect(settings.replayGain, ReplayGainMode.off);
      expect(settings.equalizerPreset, EqualizerPreset.flat);
    });

    test('saves and loads settings', () {
      final settings = PlaybackSettings(
        replayGain: ReplayGainMode.track,
        equalizerPreset: EqualizerPreset.acoustic,
        equalizerGains: Equalizer.acoustic,
        equalizerPreamp: 2.5,
        crossfade: const Duration(seconds: 2),
      );

      store.save(settings);

      expect(file.existsSync(), isTrue);

      final loadedSettings = store.load();
      expect(loadedSettings.replayGain, ReplayGainMode.track);
      expect(loadedSettings.equalizerPreset, EqualizerPreset.acoustic);
      expect(loadedSettings.equalizerGains, Equalizer.acoustic);
      expect(loadedSettings.equalizerPreamp, 2.5);
      expect(loadedSettings.crossfade, const Duration(seconds: 2));
    });

    test('creates parent directory if it does not exist on save', () {
      final nestedFile = File('${file.parent.path}/nested/dir/playback.json');
      final nestedStore = FilePlaybackSettingsStore(nestedFile);

      nestedStore.save(const PlaybackSettings());

      expect(nestedFile.existsSync(), isTrue);
    });

    test('falls back to default settings on invalid JSON', () {
      file.parent.createSync();
      file.writeAsStringSync('{ invalid json ');

      final settings = store.load();
      expect(settings.replayGain, ReplayGainMode.off);
    });

    test('handles missing fields gracefully', () {
      file.parent.createSync();
      file.writeAsStringSync('{}');

      final settings = store.load();
      expect(settings.replayGain, ReplayGainMode.off);
      expect(settings.equalizerPreset, EqualizerPreset.flat);
      expect(settings.equalizerGains, Equalizer.flat);
      expect(settings.equalizerPreamp, 0.0);
      expect(settings.crossfade, Duration.zero);
    });

    test('clamps invalid gain values', () {
      file.parent.createSync();
      file.writeAsStringSync('''
      {
        "equalizerGains": [99, -99, 0, 0, 0, 0, 0, 0, 0, 0],
        "equalizerPreamp": 50
      }
      ''');

      final settings = store.load();
      expect(settings.equalizerGains[0], Equalizer.maxGain);
      expect(settings.equalizerGains[1], Equalizer.minGain);
      expect(settings.equalizerPreamp, Equalizer.maxGain);
    });

    test('falls back to flat equalizer if gain array size is wrong', () {
      file.parent.createSync();
      file.writeAsStringSync('''
      {
        "equalizerPreset": "rock",
        "equalizerGains": [1, 2, 3],
        "equalizerPreamp": 5
      }
      ''');

      final settings = store.load();
      expect(settings.equalizerPreset, EqualizerPreset.flat);
      expect(settings.equalizerGains, Equalizer.flat);
      expect(settings.equalizerPreamp, 0.0);
    });

    test('handles incorrect types in JSON', () {
      file.parent.createSync();
      file.writeAsStringSync('''
      {
        "replayGain": 123,
        "equalizerPreset": true,
        "equalizerGains": "not an array",
        "equalizerPreamp": "string",
        "crossfadeMs": "also string"
      }
      ''');

      final settings = store.load();
      expect(settings.replayGain, ReplayGainMode.off);
      expect(settings.equalizerPreset, EqualizerPreset.flat);
      expect(settings.equalizerGains, Equalizer.flat);
      expect(settings.equalizerPreamp, 0.0);
      expect(settings.crossfade, Duration.zero);
    });
  });
}
