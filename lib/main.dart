import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/app.dart';
import 'package:studio/core/desktop/close_preference_provider.dart';
import 'package:studio/core/desktop/close_preference_store.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_settings_provider.dart';
import 'package:studio/discord/discord_settings_store.dart';
import 'package:studio/core/desktop/studio_desktop_host.dart';
import 'package:studio/core/window/window_bootstrap.dart';
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/cover_art_lookup.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scanner.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/appearance_store.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/lyrics/lyrics_cache.dart';
import 'package:studio/lyrics/lyrics_providers.dart';
import 'package:studio/playback/media_kit_bootstrap.dart';
import 'package:studio/playback/playback_session_provider.dart';
import 'package:studio/playback/playback_session_store.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/playback/playback_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final appearance = FileAppearanceStore(
    File(p.join(support.path, 'appearance.json')),
  );
  await bootstrapWindow(
    backgroundColor: StudioTheme.windowBackground(appearance.load().themeMode),
  );
  discardStaleMediaKitReferenceHolder();
  MediaKit.ensureInitialized();
  final db = StudioDatabase.onFile(File(p.join(support.path, 'studio.sqlite')));
  final artwork = ArtworkStore(Directory(p.join(support.path, 'artwork')));
  final playbackSettings = FilePlaybackSettingsStore(
    File(p.join(support.path, 'playback.json')),
  );
  final playbackSession = FilePlaybackSessionStore(
    File(p.join(support.path, 'session.json')),
  );
  final closePreference = FileClosePreferenceStore(
    File(p.join(support.path, 'close.json')),
  );
  final discordSettings = FileDiscordSettingsStore(
    File(p.join(support.path, 'discord.json')),
  );
  final discordArtwork = CatboxArtworkUploader(
    cacheFile: File(p.join(support.path, 'discord-art.json')),
  );
  runApp(
    ProviderScope(
      overrides: [
        studioDatabaseProvider.overrideWithValue(db),
        artworkStoreProvider.overrideWithValue(artwork),
        folderScannerProvider.overrideWith((ref) {
          final fetch = ref.watch(
            appearanceProvider.select((s) => s.fetchMissingArtwork),
          );
          return FolderScanner(
            db: ref.watch(studioDatabaseProvider),
            artwork: artwork,
            covers: fetch
                ? ITunesCoverArtLookup(
                    missFile: File(
                      p.join(artwork.directory.path, 'cover-misses.json'),
                    ),
                  )
                : null,
          );
        }),
        appearanceStoreProvider.overrideWithValue(appearance),
        playbackSettingsStoreProvider.overrideWithValue(playbackSettings),
        playbackSessionStoreProvider.overrideWithValue(playbackSession),
        closePreferenceStoreProvider.overrideWithValue(closePreference),
        discordSettingsStoreProvider.overrideWithValue(discordSettings),
        discordArtworkUploaderProvider.overrideWithValue(discordArtwork),
        lyricsCacheProvider.overrideWithValue(
          FileLyricsCache(Directory(p.join(support.path, 'lyrics'))),
        ),
      ],
      child: const StudioDesktopHost(child: StudioApp()),
    ),
  );
}
