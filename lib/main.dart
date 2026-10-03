import 'dart:io';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
import 'package:studio/core/network_artwork.dart';
import 'package:studio/core/desktop/close_preference_store.dart';
import 'package:studio/features/library_source/data/library_source_store.dart';
import 'package:studio/features/library_source/presentation/library_source_provider.dart';
import 'package:studio/features/mini_player/data/mini_player_store.dart';
import 'package:studio/features/mini_player/presentation/mini_player_providers.dart';
import 'package:studio/features/scrobbling/data/scrobble_queue_store.dart';
import 'package:studio/features/scrobbling/data/scrobble_settings_store.dart';
import 'package:studio/features/scrobbling/presentation/scrobble_providers.dart';
import 'package:studio/features/skins/data/skin_store.dart';
import 'package:studio/features/skins/presentation/skins_provider.dart';
import 'package:studio/features/subsonic/data/subsonic_offline_store.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_providers.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/features/updates/update_provider.dart';
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

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.any(
    (arg) => const {
      '--veloapp-install',
      '--veloapp-updated',
      '--veloapp-obsolete',
      '--veloapp-uninstall',
    }.contains(arg),
  )) {
    exit(0);
  }
  final support = await getApplicationSupportDirectory();
  NetworkArtworkCache.instance = NetworkArtworkCache(
    directory: Directory(p.join(support.path, 'artwork_cache')),
  );
  unawaited(NetworkArtworkCache.instance.prune());
  final appearance = FileAppearanceStore(
    File(p.join(support.path, 'appearance.json')),
  );
  final skins = FileSkinStore(Directory(p.join(support.path, 'skins')));
  final activeSkinId = skins.loadActive();
  await bootstrapWindow(
    backgroundColor: StudioTheme.windowBackground(
      appearance.load().themeMode,
      skin: activeSkinId == null
          ? null
          : skins.load().where((s) => s.id == activeSkinId).firstOrNull,
    ),
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
  final scrobbleSettings = SecureScrobbleSettingsStore(
    legacyFile: File(p.join(support.path, 'scrobbling.json')),
  );
  await scrobbleSettings.init();
  final scrobbleQueue = FileScrobbleQueueStore(
    File(p.join(support.path, 'scrobble-queue.json')),
  );
  final subsonicSettings = SecureSubsonicSettingsStore(
    File(p.join(support.path, 'subsonic.json')),
    const FlutterSecureStorage(),
  );
  await subsonicSettings.init();
  runApp(
    ProviderScope(
      overrides: [
        subsonicSettingsStoreProvider.overrideWithValue(subsonicSettings),
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
        scrobbleSettingsStoreProvider.overrideWithValue(scrobbleSettings),
        scrobbleQueueStoreProvider.overrideWithValue(scrobbleQueue),
        skinStoreProvider.overrideWithValue(skins),
        miniPlayerStoreProvider.overrideWithValue(
          FileMiniPlayerStore(File(p.join(support.path, 'mini_player.json'))),
        ),
        librarySourceStoreProvider.overrideWithValue(
          FileLibrarySourceStore(
            File(p.join(support.path, 'library_source.json')),
          ),
        ),
        subsonicOfflineStoreProvider.overrideWithValue(
          SubsonicOfflineStore(Directory(p.join(support.path, 'offline'))),
        ),
        lyricsCacheProvider.overrideWithValue(
          FileLyricsCache(Directory(p.join(support.path, 'lyrics'))),
        ),
      ],
      child: const StudioDesktopHost(
        child: _UpdateBootstrap(child: StudioApp()),
      ),
    ),
  );
}

class _UpdateBootstrap extends ConsumerStatefulWidget {
  const _UpdateBootstrap({required this.child});
  final Widget child;

  @override
  ConsumerState<_UpdateBootstrap> createState() => _UpdateBootstrapState();
}

class _UpdateBootstrapState extends ConsumerState<_UpdateBootstrap> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(updateServiceProvider).initialize());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
