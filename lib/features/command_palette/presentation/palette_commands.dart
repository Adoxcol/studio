import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/command_palette/domain/palette_command.dart';
import 'package:studio/features/command_palette/presentation/palette_catalog.dart';
import 'package:studio/features/mini_player/presentation/mini_player_providers.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/state/playback_provider.dart';

String get _modifier => Platform.isMacOS ? '⌘' : 'Ctrl+';

/// Everything the palette can find, built once each time it opens.
List<PaletteCommand> buildPaletteCommands(WidgetRef ref) {
  void go(StudioDestination destination) =>
      ref.read(studioNavProvider.notifier).select(destination);
  final playback = ref.read(playbackControllerProvider.notifier);
  final navigation = ref.read(libraryNavigationProvider.notifier);
  final catalog = ref.read(paletteCatalogProvider);
  final playlists = ref.read(playlistsProvider).value ?? const [];
  final tracks = ref.read(libraryIndexProvider).tracks;

  PaletteCommand screen(
    StudioDestination destination,
    String title, [
    List<String> keywords = const [],
  ]) => PaletteCommand(
    id: 'screen:${destination.name}',
    kind: PaletteKind.screen,
    title: title,
    keywords: keywords,
    run: () => go(destination),
  );

  return [
    screen(StudioDestination.library, 'Library', ['browse', 'catalogue']),
    screen(StudioDestination.nowPlaying, 'Now Playing', ['lyrics']),
    screen(StudioDestination.queue, 'Queue', ['up next', 'history']),
    screen(StudioDestination.subsonic, 'Navidrome', [
      'subsonic',
      'server',
      'offline',
      'downloads',
    ]),
    screen(StudioDestination.stats, 'Listening stats', [
      'history',
      'wrapped',
      'year in review',
      'top artists',
    ]),
    screen(StudioDestination.settings, 'Settings', [
      'preferences',
      'options',
      'equalizer',
      'theme',
      'scrobbling',
    ]),
    PaletteCommand(
      id: 'screen:playbackMode',
      kind: PaletteKind.screen,
      title: 'Playback Mode',
      keywords: const ['fullscreen', 'immersive'],
      run: ref.read(playbackModeProvider.notifier).enter,
    ),
    PaletteCommand(
      id: 'screen:miniPlayer',
      kind: PaletteKind.screen,
      title: 'Mini Player',
      keywords: const ['compact', 'always on top', 'small'],
      shortcut: '${_modifier}Shift+M',
      run: () => unawaited(ref.read(miniPlayerProvider.notifier).enter()),
    ),
    PaletteCommand(
      id: 'action:playPause',
      kind: PaletteKind.action,
      title: 'Play / Pause',
      keywords: const ['resume', 'stop'],
      shortcut: 'Space',
      run: () => unawaited(playback.togglePlayPause()),
    ),
    PaletteCommand(
      id: 'action:next',
      kind: PaletteKind.action,
      title: 'Next track',
      keywords: const ['skip'],
      run: () => unawaited(playback.skipNext()),
    ),
    PaletteCommand(
      id: 'action:previous',
      kind: PaletteKind.action,
      title: 'Previous track',
      keywords: const ['back'],
      run: () => unawaited(playback.skipPrevious()),
    ),
    PaletteCommand(
      id: 'action:shuffle',
      kind: PaletteKind.action,
      title: 'Toggle shuffle',
      keywords: const ['random'],
      run: playback.toggleShuffle,
    ),
    PaletteCommand(
      id: 'action:repeat',
      kind: PaletteKind.action,
      title: 'Cycle repeat mode',
      keywords: const ['loop'],
      run: playback.cycleRepeat,
    ),
    PaletteCommand(
      id: 'action:rescan',
      kind: PaletteKind.action,
      title: 'Rescan library folders',
      keywords: const ['refresh', 'scan', 'import'],
      run: () =>
          unawaited(ref.read(libraryScanProvider.notifier).rescanKnown()),
    ),
    for (final artist in catalog.artists)
      PaletteCommand(
        id: 'artist:${artist.name.toLowerCase()}',
        kind: PaletteKind.artist,
        title: artist.name,
        subtitle: '${artist.tracks} ${artist.tracks == 1 ? 'track' : 'tracks'}',
        run: () {
          navigation.openArtist(artist.name);
          go(StudioDestination.library);
        },
      ),
    for (final album in catalog.albums)
      PaletteCommand(
        id: 'album:${album.artist.toLowerCase()}/${album.album.toLowerCase()}',
        kind: PaletteKind.album,
        title: album.album,
        subtitle: album.artist,
        run: () {
          navigation.openAlbum(artist: album.artist, album: album.album);
          go(StudioDestination.library);
        },
      ),
    for (final playlist in playlists)
      PaletteCommand(
        id: 'playlist:${playlist.id}',
        kind: PaletteKind.playlist,
        title: playlist.name,
        subtitle: playlist.smartRules == null ? null : 'Smart playlist',
        run: () {
          navigation.openPlaylist(playlist.id);
          go(StudioDestination.library);
        },
      ),
    for (final track in tracks)
      PaletteCommand(
        id: 'track:${track.id}',
        kind: PaletteKind.track,
        title: track.title,
        subtitle: [
          ?track.artist,
          ?track.album,
        ].where((part) => part.trim().isNotEmpty).join(' — '),
        run: () => unawaited(playback.playTracks([track.id])),
      ),
  ];
}
