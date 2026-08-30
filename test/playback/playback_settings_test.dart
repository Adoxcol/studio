import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';

void main() {
  group('PlaybackSettings', () {
    test('defaults are set correctly', () {
      const settings = PlaybackSettings();

      expect(settings.replayGain, ReplayGainMode.off);
      expect(settings.equalizerPreset, EqualizerPreset.flat);
      expect(settings.equalizerGains, Equalizer.flat);
      expect(settings.equalizerPreamp, 0.0);
      expect(settings.crossfade, Duration.zero);
    });

    test('defaults constant matches empty constructor', () {
      expect(PlaybackSettings.defaults.replayGain, ReplayGainMode.off);
      expect(PlaybackSettings.defaults.equalizerPreset, EqualizerPreset.flat);
      expect(PlaybackSettings.defaults.equalizerGains, Equalizer.flat);
      expect(PlaybackSettings.defaults.equalizerPreamp, 0.0);
      expect(PlaybackSettings.defaults.crossfade, Duration.zero);
    });

    test('copyWith updates specified properties', () {
      const settings = PlaybackSettings();

      final updated = settings.copyWith(
        replayGain: ReplayGainMode.track,
        equalizerPreset: EqualizerPreset.rock,
        equalizerGains: Equalizer.bass,
        equalizerPreamp: 5.0,
        crossfade: const Duration(seconds: 5),
      );

      expect(updated.replayGain, ReplayGainMode.track);
      expect(updated.equalizerPreset, EqualizerPreset.rock);
      expect(updated.equalizerGains, Equalizer.bass);
      expect(updated.equalizerPreamp, 5.0);
      expect(updated.crossfade, const Duration(seconds: 5));
    });

    test('copyWith retains unmodified properties', () {
      const settings = PlaybackSettings(
        replayGain: ReplayGainMode.album,
        equalizerPreset: EqualizerPreset.jazz,
        equalizerGains: Equalizer.acoustic,
        equalizerPreamp: 2.5,
        crossfade: Duration(seconds: 2),
      );

      final updated = settings.copyWith(replayGain: ReplayGainMode.track);

      expect(updated.replayGain, ReplayGainMode.track);
      expect(updated.equalizerPreset, EqualizerPreset.jazz);
      expect(updated.equalizerGains, Equalizer.acoustic);
      expect(updated.equalizerPreamp, 2.5);
      expect(updated.crossfade, const Duration(seconds: 2));
    });

    test(
      'activeEqualizerGains returns preset gains for non-custom presets',
      () {
        const settings = PlaybackSettings(
          equalizerPreset: EqualizerPreset.rock,
          equalizerGains:
              Equalizer.flat, // Should be ignored since preset is rock
        );

        expect(settings.activeEqualizerGains, Equalizer.rock);
      },
    );

    test('activeEqualizerGains returns custom gains for custom preset', () {
      const settings = PlaybackSettings(
        equalizerPreset: EqualizerPreset.custom,
        equalizerGains: Equalizer.bass,
      );

      expect(settings.activeEqualizerGains, Equalizer.bass);
    });
  });
}
