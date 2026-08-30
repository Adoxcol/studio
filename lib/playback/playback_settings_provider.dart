import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/equalizer_import.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';
import 'package:studio/state/library_providers.dart';

final playbackSettingsStoreProvider = Provider<PlaybackSettingsStore>((ref) {
  return MemoryPlaybackSettingsStore();
});

class PlaybackSettingsNotifier extends Notifier<PlaybackSettings> {
  @override
  PlaybackSettings build() {
    return ref.watch(playbackSettingsStoreProvider).load();
  }

  void setReplayGain(ReplayGainMode mode) {
    state = state.copyWith(replayGain: mode);
    ref.read(playbackSettingsStoreProvider).save(state);
    ref.read(audioEngineProvider).setReplayGain(mode);
  }

  void setEqualizerPreset(EqualizerPreset preset) {
    final gains = Equalizer.gainsFor(preset, state.equalizerGains);
    final preamp =
        preset == EqualizerPreset.custom ? state.equalizerPreamp : 0.0;
    state = state.copyWith(
      equalizerPreset: preset,
      equalizerGains: gains,
      equalizerPreamp: preamp,
    );
    ref.read(playbackSettingsStoreProvider).save(state);
    ref.read(audioEngineProvider).setEqualizer(gains, preamp: preamp);
  }

  void setEqualizerBand(int index, double gain) {
    if (index < 0 || index >= Equalizer.bandsHz.length) return;
    final next = List<double>.from(state.activeEqualizerGains);
    next[index] = Equalizer.clampGain(gain);
    state = state.copyWith(
      equalizerPreset: EqualizerPreset.custom,
      equalizerGains: next,
    );
    ref.read(playbackSettingsStoreProvider).save(state);
    ref
        .read(audioEngineProvider)
        .setEqualizer(next, preamp: state.equalizerPreamp);
  }

  void importEqualizer(ImportedEqualizer imported) {
    state = state.copyWith(
      equalizerPreset: EqualizerPreset.custom,
      equalizerGains: imported.gains,
      equalizerPreamp: Equalizer.clampGain(imported.preamp),
    );
    ref.read(playbackSettingsStoreProvider).save(state);
    ref
        .read(audioEngineProvider)
        .setEqualizer(imported.gains, preamp: state.equalizerPreamp);
  }

  void importEqualizerText(String contents) {
    importEqualizer(EqualizerImport.parse(contents));
  }

  void setCrossfade(Duration duration) {
    state = state.copyWith(crossfade: duration);
    ref.read(playbackSettingsStoreProvider).save(state);
    ref.read(audioEngineProvider).setCrossfade(duration);
  }
}

final playbackSettingsProvider =
    NotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>(
  PlaybackSettingsNotifier.new,
);
