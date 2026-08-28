import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

final playbackSettingsProvider =
    NotifierProvider<PlaybackSettingsNotifier, PlaybackSettings>(
      PlaybackSettingsNotifier.new,
    );
