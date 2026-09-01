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

  void setFullPlayerSection(FullPlayerSection section, bool show) {
    state = switch (section) {
      FullPlayerSection.albumArt => state.copyWith(fullPlayerAlbumArt: show),
      FullPlayerSection.artistArt => state.copyWith(fullPlayerArtistArt: show),
      FullPlayerSection.lyrics => state.copyWith(fullPlayerLyrics: show),
      FullPlayerSection.fileInfo => state.copyWith(fullPlayerFileInfo: show),
      FullPlayerSection.audioSettings => state.copyWith(
        fullPlayerAudioSettings: show,
      ),
    };
    ref.read(appearanceStoreProvider).save(state);
  }
}

enum FullPlayerSection { albumArt, artistArt, lyrics, fileInfo, audioSettings }

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
      AppearanceNotifier.new,
    );

final artworkHueCacheProvider = Provider<ArtworkHueCache>((ref) {
  final cache = ArtworkHueCache();
  ref.onDispose(cache.dispose);
  return cache;
});

final artworkHueProvider = FutureProvider.autoDispose<double?>((ref) async {
  final path = ref.watch(
    playbackControllerProvider.select((s) => s.artworkPath),
  );
  if (path == null) return null;
  return ref.watch(artworkHueCacheProvider).read(path);
});

/// Hue actually applied to the theme: custom swatch, or art, or terracotta.
final resolvedAccentHueProvider = Provider<double>((ref) {
  final appearance = ref.watch(appearanceProvider);
  if (appearance.mode == AccentMode.custom) {
    return appearance.customHue;
  }
  return ref.watch(artworkHueProvider).value ?? AccentSeed.defaultHue;
});
