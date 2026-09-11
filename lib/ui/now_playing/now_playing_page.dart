import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/library_providers.dart'
    show libraryTracksByIdProvider, spectrumBandsProvider;
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/lyrics/lyrics_scroller.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/now_playing/editorial_stage.dart';
import 'package:studio/ui/track_actions/track_actions_menu.dart';
import 'package:studio/ui/visualizer/spectrum_visualizer.dart';

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  static const double artSize = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      playbackControllerProvider.select(
        (s) => (
          title: s.title,
          artist: s.artist,
          artworkPath: s.artworkPath,
          trackId: s.trackId,
        ),
      ),
    );
    return _ClassicNowPlayingHero(
      title: snapshot.title,
      artist: snapshot.artist,
      artworkPath: snapshot.artworkPath,
      trackId: snapshot.trackId,
    );
  }
}

class _ClassicNowPlayingHero extends ConsumerWidget {
  const _ClassicNowPlayingHero({
    required this.title,
    required this.artist,
    required this.artworkPath,
    required this.trackId,
  });

  final String title;
  final String? artist;
  final String? artworkPath;
  final int? trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final hasTrack = trackId != null;
    final track = trackId == null
        ? null
        : ref.watch(libraryTracksByIdProvider)[trackId];
    return LayoutBuilder(
      builder: (context, constraints) {
        const visualizerHeight = 44.0;
        const visualizerBlock = 16 + visualizerHeight + 24;
        const verticalPad = 48.0;
        final titleStyle = Theme.of(context).textTheme.displayLarge;
        final titleLine =
            (titleStyle?.fontSize ?? 44) * (titleStyle?.height ?? 1.05);
        final reserved =
            verticalPad +
            visualizerBlock +
            (hasTrack ? 28.0 : 0.0) +
            titleLine * (hasTrack ? 2 : 1) +
            (artist != null ? 26.0 : 0.0);
        final artSize = [
          NowPlayingPage.artSize,
          (constraints.maxWidth - 64).clamp(64.0, NowPlayingPage.artSize),
          (constraints.maxHeight - reserved).clamp(
            64.0,
            NowPlayingPage.artSize,
          ),
        ].reduce((a, b) => a < b ? a : b);
        final innerHeight = (constraints.maxHeight - verticalPad).clamp(
          0.0,
          double.infinity,
        );
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                CoverArt(path: artworkPath, size: artSize),
                if (track != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: TrackActionsButton(
                        track: track,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _VisualizerSlot(width: artSize),
            const SizedBox(height: 24),
            if (hasTrack)
              Text(
                'now playing',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.inkMutedAlt,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (hasTrack) const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (artist != null) ...[
              const SizedBox(height: 8),
              _ArtistByline(artist: artist!),
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: hasTrack
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: innerHeight),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: (constraints.maxWidth - 64).clamp(
                      0.0,
                      double.infinity,
                    ),
                    child: header,
                  ),
                ),
              ),
              if (hasTrack) const Expanded(child: LyricsPane()),
            ],
          ),
        );
      },
    );
  }
}

class PlaybackModePage extends ConsumerWidget {
  const PlaybackModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): ref
            .read(playbackModeProvider.notifier)
            .exit,
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) ref.read(playbackModeProvider.notifier).exit();
          },
          child: const EditorialStage(),
        ),
      ),
    );
  }
}

class PlaybackModeWidget extends ConsumerWidget {
  const PlaybackModeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EditorialStage(embedded: true);
  }
}

class _PermanentPlaybackBackground extends StatelessWidget {
  const _PermanentPlaybackBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Color(0xff12110f)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.72, -0.48),
              radius: 1.15,
              colors: [Color(0x995f3027), Color(0x00412520)],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.8, 0.25),
              radius: 1.05,
              colors: [Color(0x55334f4a), Color(0x00121715)],
            ),
          ),
        ),
      ],
    );
  }
}

class PlaybackBackground extends ConsumerWidget {
  const PlaybackBackground({
    super.key,
    required this.mode,
    required this.albumPath,
    required this.artist,
  });
  final PlaybackBackgroundMode mode;
  final String? albumPath;
  final String? artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistPath =
        mode == PlaybackBackgroundMode.artistImage && artist != null
        ? ref.watch(artistPictureProvider(artist!)).value?.path
        : null;
    final path = switch (mode) {
      PlaybackBackgroundMode.albumArtwork => albumPath,
      PlaybackBackgroundMode.artistImage => artistPath ?? albumPath,
      _ => null,
    };
    final background = switch (mode) {
      PlaybackBackgroundMode.solidColor => const ColoredBox(
        color: Color(0xff201b18),
      ),
      _ => Stack(
        fit: StackFit.expand,
        children: [
          const _PermanentPlaybackBackground(),
          if (path != null && path.isNotEmpty)
            Opacity(
              opacity: 0.52,
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                color: const Color(0xffb7a99a),
                colorBlendMode: BlendMode.modulate,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey('${mode.name}-${path ?? ''}'),
        child: background,
      ),
    );
  }
}

class FullPlayerMenu extends ConsumerWidget {
  const FullPlayerMenu({super.key, required this.appearance});
  final AppearanceState appearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final values = <FullPlayerSection, (String, bool)>{
      FullPlayerSection.albumArt: (
        'Album cover',
        appearance.fullPlayerAlbumArt,
      ),
      FullPlayerSection.artistArt: (
        'Artist picture',
        appearance.fullPlayerArtistArt,
      ),
      FullPlayerSection.lyrics: ('Lyrics', appearance.fullPlayerLyrics),
      FullPlayerSection.fileInfo: (
        'File information',
        appearance.fullPlayerFileInfo,
      ),
      FullPlayerSection.audioSettings: (
        'Audio settings',
        appearance.fullPlayerAudioSettings,
      ),
    };
    return PopupMenuButton<Object>(
      tooltip: 'Customize Full Player',
      icon: const Icon(Icons.tune, size: 19),
      onSelected: (selection) {
        final notifier = ref.read(appearanceProvider.notifier);
        if (selection case final FullPlayerSection section) {
          notifier.setFullPlayerSection(section, !values[section]!.$2);
        } else if (selection case final PlaybackBackgroundMode mode) {
          notifier.setFullPlayerBackground(mode);
        }
      },
      itemBuilder: (_) => [
        for (final entry in values.entries)
          PopupMenuItem(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  entry.value.$2
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: entry.value.$2 ? palette.accent : palette.inkMutedAlt,
                ),
                const SizedBox(width: 10),
                Text(entry.value.$1),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<Object>(
          enabled: false,
          height: 30,
          child: Text('Background'),
        ),
        for (final mode in PlaybackBackgroundMode.values)
          PopupMenuItem<Object>(
            value: mode,
            child: Row(
              children: [
                Icon(
                  appearance.fullPlayerBackground == mode
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: appearance.fullPlayerBackground == mode
                      ? palette.accent
                      : palette.inkMutedAlt,
                ),
                const SizedBox(width: 10),
                Text(mode.label),
              ],
            ),
          ),
      ],
    );
  }
}

class _ArtistByline extends ConsumerWidget {
  const _ArtistByline({required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final artists = LibraryQuery.creditedArtists(artist);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: palette.inkMuted,
      fontStyle: FontStyle.italic,
    );

    void open(String name) {
      ref.read(libraryNavigationProvider.notifier).openArtist(name);
      ref.read(studioNavProvider.notifier).select(StudioDestination.library);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < artists.length; index++) ...[
          if (index > 0) Text(' · ', style: style),
          TextButton(
            key: ValueKey('now-playing-artist-${artists[index]}'),
            onPressed: () => open(artists[index]),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: WidgetStateProperty.resolveWith(
                (states) => style?.copyWith(
                  decoration: states.contains(WidgetState.hovered)
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: palette.inkMuted,
                  decorationThickness: 1,
                ),
              ),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              foregroundColor: WidgetStatePropertyAll(palette.inkMuted),
            ),
            child: Text(artists[index]),
          ),
        ],
      ],
    );
  }
}

class _VisualizerSlot extends ConsumerWidget {
  const _VisualizerSlot({required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      playbackControllerProvider.select((s) => s.playing),
    );
    final bands = ref.watch(spectrumBandsProvider).value ?? const [];
    return SpectrumVisualizer(playing: playing, bands: bands, width: width);
  }
}
