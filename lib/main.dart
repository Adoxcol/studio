import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/app.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/features/artist_artwork/presentation/fanart_settings.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/data/musicbrainz_artist_picture_lookup.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
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
  final discordArtwork = FreeImageArtworkUploader(
    cacheFile: File(p.join(support.path, 'discord-art.json')),
  );
  runApp(
    ProviderScope(
      overrides: [
        fanartSettingsStoreProvider.overrideWithValue(
          FanartSettingsStore(file: File(p.join(support.path, 'fanart.json'))),
        ),
        studioDatabaseProvider.overrideWithValue(db),
        artworkStoreProvider.overrideWithValue(artwork),
        artistPictureRepositoryProvider.overrideWith((ref) {
          final log = ArtistPictureLog(debugPrint);
          var fanart = ref.read(fanartSettingsProvider);
          final lookup = MusicBrainzArtistPictureLookup(
            log: log,
            enableAudioDb: true,
            fanart: fanart,
            identities: ArtistIdentityStore(
              directory: Directory(p.join(support.path, 'artist-identities')),
            ),
          );
          log(
            fanart.enabled
                ? 'fanart.tv configured; credentials omitted from logs.'
                : 'fanart.tv is not configured. Add keys in Settings to enable it.',
          );
          final repository = ArtistPictureRepository(
            store: FileArtistPictureStore(
              Directory(p.join(support.path, 'artist-pictures')),
              sourceRevision: () => fanart.revision,
            ),
            lookup: lookup,
            log: log,
          );
          ref.listen(fanartSettingsProvider, (_, next) {
            fanart = next;
            lookup.configureFanart(next);
            repository.refreshSources().catchError((Object _) {
              log(
                'Could not refresh image cache after settings change; restart Studio to retry.',
              );
            });
          });
          ref.onDispose(repository.dispose);
          return repository;
        }),
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
