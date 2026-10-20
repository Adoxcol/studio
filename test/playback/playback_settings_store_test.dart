import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  group('PlaybackSettingsStore', () {
    test('MemoryPlaybackSettingsStore loadAsync returns value', () async {
      final store = MemoryPlaybackSettingsStore();
      final loaded = await store.loadAsync();
      expect(loaded, PlaybackSettings.defaults);
    });

    test('FilePlaybackSettingsStore loadAsync loads asynchronously', () async {
      final tempDir = Directory.systemTemp.createTempSync('studio-settings');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final file = File('${tempDir.path}/playback.json');
      file.writeAsStringSync(
        '{"replayGain":"track","equalizerPreset":"pop","crossfadeMs":3000}',
      );

      final store = FilePlaybackSettingsStore(file);
      final loaded = await store.loadAsync();

      expect(loaded.replayGain, ReplayGainMode.track);
      expect(loaded.equalizerPreset, EqualizerPreset.pop);
      expect(loaded.crossfade, const Duration(milliseconds: 3000));

      // Subsequent synchronous load uses cached result
      expect(store.load().replayGain, ReplayGainMode.track);
    });

    test('FilePlaybackSettingsStore handles missing or corrupt file', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'studio-settings-bad',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final missingFile = File('${tempDir.path}/missing.json');
      final missingStore = FilePlaybackSettingsStore(missingFile);
      expect(await missingStore.loadAsync(), PlaybackSettings.defaults);

      final corruptFile = File('${tempDir.path}/corrupt.json')
        ..writeAsStringSync('{invalid json');
      final corruptStore = FilePlaybackSettingsStore(corruptFile);
      expect(await corruptStore.loadAsync(), PlaybackSettings.defaults);
    });
  });
}
