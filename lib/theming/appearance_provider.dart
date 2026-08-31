import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_store.dart';
import 'package:studio/theming/artwork_hue.dart';

final appearanceStoreProvider = Provider<AppearanceStore>((ref) {
  return MemoryAppearanceStore();
});

class AppearanceNotifier extends Notifier<AppearanceState> {
  @override
  AppearanceState build() => ref.watch(appearanceStoreProvider).load();

  void setMode(AccentMode mode) {
    state = state.copyWith(mode: mode);
    ref.read(appearanceStoreProvider).save(state);
  }

  void setCustomHue(double hue) {
    state = state.copyWith(
      mode: AccentMode.custom,
      customHue: AccentSeed.wrap(hue),
    );
    ref.read(appearanceStoreProvider).save(state);
  }

  void setTrackLayout(TrackLayout layout) {
    state = state.copyWith(trackLayout: layout);
    ref.read(appearanceStoreProvider).save(state);
  }

  void setShowTrackArtwork(bool show) {
    state = state.copyWith(showTrackArtwork: show);
    ref.read(appearanceStoreProvider).save(state);
  }

  void setFetchMissingArtwork(bool fetch) {
    state = state.copyWith(fetchMissingArtwork: fetch);
    ref.read(appearanceStoreProvider).save(state);
  }

  void setThemeMode(AppThemeMode themeMode) {
    state = state.copyWith(themeMode: themeMode);
    ref.read(appearanceStoreProvider).save(state);
  }

  void setFetchArtistPictures(bool fetch) {
    state = state.copyWith(fetchArtistPictures: fetch);
    ref.read(appearanceStoreProvider).save(state);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
      AppearanceNotifier.new,
    );

final artworkHueProvider = FutureProvider<double?>((ref) async {
  final path = ref.watch(
    playbackControllerProvider.select((s) => s.artworkPath),
  );
  if (path == null) return null;
  return hueFromArtwork(path);
});

/// Hue actually applied to the theme: custom swatch, or art, or terracotta.
final resolvedAccentHueProvider = Provider<double>((ref) {
  final appearance = ref.watch(appearanceProvider);
  if (appearance.mode == AccentMode.custom) {
    return appearance.customHue;
  }
  return ref.watch(artworkHueProvider).value ?? AccentSeed.defaultHue;
});
