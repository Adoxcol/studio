import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/state/library_providers.dart'
    show libraryTracksByIdProvider, spectrumBandsProvider;
import 'package:studio/library/library_query.dart';
import 'package:studio/discord/discord_template.dart';
import 'package:studio/features/artist_artwork/presentation/artist_portrait.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/lyrics/lyrics_scroller.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
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
    final playback = ref.watch(playbackControllerProvider);
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
          child: _PlaybackModeHero(playback: playback),
        ),
      ),
    );
  }
}

class PlaybackModeWidget extends ConsumerWidget {
  const PlaybackModeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlaybackModeHero(
      playback: ref.watch(playbackControllerProvider),
      embedded: true,
    );
  }
}

class _PlaybackModeHero extends ConsumerWidget {
  const _PlaybackModeHero({required this.playback, this.embedded = false});
  final PlaybackUiState playback;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final hasTrack = playback.trackId != null;
    final artist = playback.artist;
    final creditedArtist = artist == null
        ? null
        : LibraryQuery.creditedArtists(artist).first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final lowHeight = constraints.maxHeight < 620;
        final ultrawide = constraints.maxWidth >= 1500;
        final compact = embedded || narrow || lowHeight;
        final artSize = lowHeight
            ? 76.0
            : narrow
            ? 88.0
            : embedded
            ? 118.0
            : 210.0;
        final lyricsWidth = narrow || embedded
            ? double.infinity
            : ultrawide
            ? constraints.maxWidth * 0.42
            : 680.0;
        return ColoredBox(
          color: const Color(0xff171713),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _PlaybackBackground(
                mode: appearance.fullPlayerBackground,
                albumPath: playback.artworkPath,
                artist: creditedArtist,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x66000000),
                      Color(0xee090908),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 28,
                    compact ? 8 : 18,
                    compact ? 14 : 28,
                    compact ? 10 : 24,
                  ),
                  child: Column(
                    children: [
                      _PlaybackModeTopBar(
                        appearance: appearance,
                        embedded: embedded,
                      ),
                      if (hasTrack && appearance.fullPlayerLyrics)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: lyricsWidth,
                              child: const _ImmersiveLyrics(),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Row(
                          key: ValueKey(playback.trackId),
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (appearance.fullPlayerAlbumArt) ...[
                              CoverArt(
                                path: playback.artworkPath,
                                size: artSize,
                              ),
                              SizedBox(width: compact ? 14 : 28),
                            ],
                            if (!compact &&
                                appearance.fullPlayerArtistArt &&
                                creditedArtist != null) ...[
                              ArtistPortrait(artist: creditedArtist, size: 120),
                              const SizedBox(width: 22),
                            ],
                            Expanded(
                              child: _ImmersiveMetadata(
                                playback: playback,
                                showFileInfo: appearance.fullPlayerFileInfo,
                                compact: compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 24),
                      _ImmersiveProgress(playback: playback),
                      SizedBox(height: lowHeight ? 2 : 10),
                      _ImmersiveTransport(compact: lowHeight),
                      if (hasTrack && appearance.fullPlayerAudioSettings) ...[
                        SizedBox(height: compact ? 6 : 14),
                        _ImmersiveAudioSettings(compact: compact),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImmersiveLyrics extends StatelessWidget {
  const _ImmersiveLyrics();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, 0.16, 0.84, 1],
      ).createShader(bounds),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: LyricsPane(immersive: true),
      ),
    );
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

class _PlaybackBackground extends ConsumerWidget {
  const _PlaybackBackground({
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

class _PlaybackModeTopBar extends ConsumerWidget {
  const _PlaybackModeTopBar({required this.appearance, required this.embedded});
  final AppearanceState appearance;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        if (!embedded) ...[
          IconButton(
            tooltip: 'Exit Playback Mode',
            onPressed: ref.read(playbackModeProvider.notifier).exit,
            color: Colors.white,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
        ],
        const Text(
          'PLAYBACK MODE',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Theme(
          data: Theme.of(
            context,
          ).copyWith(iconTheme: const IconThemeData(color: Colors.white)),
          child: _FullPlayerMenu(appearance: appearance),
        ),
        if (!embedded)
          IconButton(
            tooltip: 'Exit Playback Mode',
            onPressed: ref.read(playbackModeProvider.notifier).exit,
            color: Colors.white,
            icon: const Icon(Icons.fullscreen_exit),
          ),
      ],
    );
  }
}

class _ImmersiveMetadata extends ConsumerWidget {
  const _ImmersiveMetadata({
    required this.playback,
    required this.showFileInfo,
    required this.compact,
  });
  final PlaybackUiState playback;
  final bool showFileInfo;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = (playback.album ?? '').trim();
    final track = playback.trackId == null
        ? null
        : ref.watch(libraryTracksByIdProvider)[playback.trackId];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playback.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 26 : 38,
            height: 1.05,
          ),
        ),
        if (playback.artist != null) ...[
          const SizedBox(height: 8),
          _ImmersiveArtistByline(artist: playback.artist!),
        ],
        if (album.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            album,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
        if (showFileInfo) ...[
          const SizedBox(height: 9),
          _FileInformation(playback: playback, immersive: true),
        ],
        if (track != null)
          TrackActionsButton(track: track, color: Colors.white70),
      ],
    );
  }
}

class _ImmersiveProgress extends ConsumerWidget {
  const _ImmersiveProgress({required this.playback});
  final PlaybackUiState playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final durationMs = playback.duration.inMilliseconds;
    final value = durationMs <= 0
        ? 0.0
        : (playback.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            formatDuration(playback.position),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              overlayColor: Colors.white12,
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              onChanged: ref
                  .read(playbackControllerProvider.notifier)
                  .seekFraction,
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            formatDuration(playback.duration),
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _ImmersiveTransport extends ConsumerWidget {
  const _ImmersiveTransport({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: controller.toggleShuffle,
          color: state.shuffle ? Colors.white : Colors.white54,
          icon: const Icon(Icons.shuffle),
        ),
        IconButton(
          onPressed: controller.skipPrevious,
          color: Colors.white,
          iconSize: compact ? 24 : 30,
          icon: const Icon(Icons.skip_previous),
        ),
        SizedBox(width: compact ? 2 : 8),
        IconButton.filled(
          tooltip: state.playing ? 'Pause' : 'Play',
          onPressed: controller.togglePlayPause,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            minimumSize: Size.square(compact ? 42 : 52),
          ),
          icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
        ),
        SizedBox(width: compact ? 2 : 8),
        IconButton(
          onPressed: controller.skipNext,
          color: Colors.white,
          iconSize: compact ? 24 : 30,
          icon: const Icon(Icons.skip_next),
        ),
        IconButton(
          onPressed: controller.cycleRepeat,
          color: state.repeat == QueueRepeatMode.off
              ? Colors.white54
              : Colors.white,
          icon: Icon(
            state.repeat == QueueRepeatMode.one
                ? Icons.repeat_one
                : Icons.repeat,
          ),
        ),
      ],
    );
  }
}

class _ImmersiveAudioSettings extends StatelessWidget {
  const _ImmersiveAudioSettings({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 18,
          vertical: compact ? 3 : 8,
        ),
        child: const DefaultTextStyle(
          style: TextStyle(color: Colors.white70, fontSize: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _AudioSettings(immersive: true),
          ),
        ),
      ),
    );
  }
}

class _FullPlayerMenu extends ConsumerWidget {
  const _FullPlayerMenu({required this.appearance});
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

class _FileInformation extends StatelessWidget {
  const _FileInformation({required this.playback, this.immersive = false});
  final PlaybackUiState playback;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final values = discordTemplateValues(playback);
    final items = [
      values['filename']!,
      values['quality']!,
      if ((playback.genre ?? '').trim().isNotEmpty) playback.genre!.trim(),
    ].where((value) => value.isNotEmpty).toList();
    return Text(
      items.isEmpty ? 'File information unavailable' : items.join('  ·  '),
      textAlign: immersive ? TextAlign.start : TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: immersive ? Colors.white70 : palette.inkMuted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _AudioSettings extends ConsumerWidget {
  const _AudioSettings({this.immersive = false});
  final bool immersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playbackSettingsProvider);
    final notifier = ref.read(playbackSettingsProvider.notifier);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 22,
      runSpacing: 10,
      children: [
        Text(
          'ReplayGain',
          style: immersive
              ? const TextStyle(color: Colors.white)
              : Theme.of(context).textTheme.bodySmall,
        ),
        for (final mode in ReplayGainMode.values)
          if (immersive)
            TextButton(
              onPressed: () => notifier.setReplayGain(mode),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: settings.replayGain == mode
                    ? Colors.white
                    : Colors.white54,
              ),
              child: Text(mode.label),
            )
          else
            LibraryTextAction(
              label: mode.label,
              muted: settings.replayGain != mode,
              onTap: () => notifier.setReplayGain(mode),
            ),
        Text(
          'Crossfade',
          style: immersive
              ? const TextStyle(color: Colors.white)
              : Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButton<Duration>(
          value: settings.crossfade,
          dropdownColor: immersive ? const Color(0xff242421) : null,
          style: immersive ? const TextStyle(color: Colors.white) : null,
          underline: const SizedBox.shrink(),
          items: [
            for (var seconds = 0; seconds <= 15; seconds++)
              DropdownMenuItem(
                value: Duration(seconds: seconds),
                child: Text(seconds == 0 ? 'Off' : '${seconds}s'),
              ),
          ],
          onChanged: (value) {
            if (value != null) notifier.setCrossfade(value);
          },
        ),
        Text(
          'EQ',
          style: immersive
              ? const TextStyle(color: Colors.white)
              : Theme.of(context).textTheme.bodySmall,
        ),
        DropdownButton<EqualizerPreset>(
          value: settings.equalizerPreset,
          dropdownColor: immersive ? const Color(0xff242421) : null,
          style: immersive ? const TextStyle(color: Colors.white) : null,
          underline: const SizedBox.shrink(),
          items: [
            for (final preset in EqualizerPreset.values)
              DropdownMenuItem(value: preset, child: Text(preset.label)),
          ],
          onChanged: (value) {
            if (value != null) notifier.setEqualizerPreset(value);
          },
        ),
      ],
    );
  }
}

class _ImmersiveArtistByline extends ConsumerWidget {
  const _ImmersiveArtistByline({required this.artist});
  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = LibraryQuery.creditedArtists(artist);
    void open(String name) {
      ref.read(libraryNavigationProvider.notifier).openArtist(name);
      ref.read(playbackModeProvider.notifier).exit();
      ref.read(studioNavProvider.notifier).select(StudioDestination.library);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < artists.length; index++) ...[
          if (index > 0)
            const Text('  ·  ', style: TextStyle(color: Colors.white54)),
          TextButton(
            onPressed: () => open(artists[index]),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size.zero),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              foregroundColor: const WidgetStatePropertyAll(Colors.white70),
              textStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  fontSize: 16,
                  decoration: states.contains(WidgetState.hovered)
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: Colors.white70,
                ),
              ),
            ),
            child: Text(artists[index]),
          ),
        ],
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
