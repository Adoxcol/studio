import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/playback/dsp/equalizer.dart';
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
    state = state.copyWith(equalizerPreset: preset, equalizerGains: gains);
    ref.read(playbackSettingsStoreProvider).save(state);
    ref.read(audioEngineProvider).setEqualizer(gains);
  }

  void setEqualizerBand(int index, double gain) {
    if (index < 0 || index >= Equalizer.bandsHz.length) return;
    final next = List<double>.from(state.activeEqualizerGains);
    next[index] = gain.clamp(Equalizer.minGain, Equalizer.maxGain).toDouble();
    state = state.copyWith(
      equalizerPreset: EqualizerPreset.custom,
      equalizerGains: next,
    );
    ref.read(playbackSettingsStoreProvider).save(state);
    ref.read(audioEngineProvider).setEqualizer(next);
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
