import 'dart:convert';
import 'dart:io';

import 'package:studio/theming/accent_seed.dart';

abstract class AppearanceStore {
  Future<AppearanceState> loadAsync() async => load();
  AppearanceState load();
  void save(AppearanceState state);
}

class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.value = AppearanceState.defaults]);

  AppearanceState value;

  @override
  Future<AppearanceState> loadAsync() async => value;

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
  AppearanceState? _cache;
  Future<AppearanceState>? _loading;

  @override
  Future<AppearanceState> loadAsync() async {
    if (_cache != null) return _cache!;
    if (_loading != null) return _loading!;

    return _loading = Future(() async {
      if (!await file.exists()) return AppearanceState.defaults;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final modeName = json['mode'] as String?;
        final hue = (json['customHue'] as num?)?.toDouble();
        return _cache = AppearanceState(
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
        return _cache = AppearanceState.defaults;
      }
    });
  }

  @override
  AppearanceState load() {
    if (_cache != null) return _cache!;
    if (!file.existsSync()) return AppearanceState.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final modeName = json['mode'] as String?;
      final hue = (json['customHue'] as num?)?.toDouble();
      return _cache = AppearanceState(
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
      return _cache = AppearanceState.defaults;
    }
  }

  @override
  void save(AppearanceState state) {
    _cache = state;
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(
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
      flush: true,
    );
    part.renameSync(file.path);
  }
}
