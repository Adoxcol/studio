import 'dart:convert';
import 'dart:io';

import 'package:studio/theming/accent_seed.dart';

abstract class AppearanceStore {
  AppearanceState load();
  void save(AppearanceState state);
}

class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.value = AppearanceState.defaults]);

  AppearanceState value;

  @override
  AppearanceState load() => value;

  @override
  void save(AppearanceState state) {
    value = state;
  }
}

class FileAppearanceStore implements AppearanceStore {
  FileAppearanceStore(this.file);

  final File file;

  @override
  AppearanceState load() {
    if (!file.existsSync()) return AppearanceState.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final modeName = json['mode'] as String?;
      final hue = (json['customHue'] as num?)?.toDouble();
      return AppearanceState(
        mode: modeName == 'custom' ? AccentMode.custom : AccentMode.auto,
        customHue: hue ?? AccentSeed.defaultHue,
        trackLayout: TrackLayout.fromName(json['trackLayout'] as String?),
        showTrackArtwork: json['showTrackArtwork'] as bool? ?? true,
        fetchMissingArtwork: json['fetchMissingArtwork'] as bool? ?? true,
        fetchArtistPictures: json['fetchArtistPictures'] as bool? ?? true,
        themeMode: AppThemeMode.fromName(json['themeMode'] as String?),
        fullPlayerAlbumArt: json['fullPlayerAlbumArt'] as bool? ?? true,
        fullPlayerArtistArt: json['fullPlayerArtistArt'] as bool? ?? true,
        fullPlayerLyrics: json['fullPlayerLyrics'] as bool? ?? true,
        fullPlayerFileInfo: json['fullPlayerFileInfo'] as bool? ?? true,
        fullPlayerAudioSettings:
            json['fullPlayerAudioSettings'] as bool? ?? true,
        fullPlayerBackground: PlaybackBackgroundMode.fromName(
          json['fullPlayerBackground'] as String?,
        ),
      );
    } on Object {
      return AppearanceState.defaults;
    }
  }

  @override
  void save(AppearanceState state) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'mode': state.mode.name,
        'customHue': state.customHue,
        'trackLayout': state.trackLayout.name,
        'showTrackArtwork': state.showTrackArtwork,
        'fetchMissingArtwork': state.fetchMissingArtwork,
        'fetchArtistPictures': state.fetchArtistPictures,
        'themeMode': state.themeMode.name,
        'fullPlayerAlbumArt': state.fullPlayerAlbumArt,
        'fullPlayerArtistArt': state.fullPlayerArtistArt,
        'fullPlayerLyrics': state.fullPlayerLyrics,
        'fullPlayerFileInfo': state.fullPlayerFileInfo,
        'fullPlayerAudioSettings': state.fullPlayerAudioSettings,
        'fullPlayerBackground': state.fullPlayerBackground.name,
      }),
    );
  }
}
