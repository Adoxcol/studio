import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/discord/discord_template.dart';
import 'package:studio/features/artist_artwork/presentation/artist_portrait.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/audio_engine_sheet.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/now_playing/editorial_lyrics.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/now_playing/vinyl_sleeve.dart';
import 'package:studio/ui/track_actions/track_actions_menu.dart';

/// Fullscreen Editorial Audio Environment playback stage.
class EditorialStage extends ConsumerWidget {
  const EditorialStage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final appearance = ref.watch(appearanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageMode = ref.watch(editorialStageModeProvider);
    final coverMode = ref.watch(editorialCoverModeProvider);
    final showTopBar = ref.watch(editorialShowTopBarProvider);
    final playback = ref.watch(playbackControllerProvider);
    final track = playback.trackId == null
        ? null
        : ref.watch(libraryTracksByIdProvider)[playback.trackId];

    final artist = playback.artist;
    final creditedArtist = artist == null
        ? null
        : LibraryQuery.creditedArtists(artist).firstOrNull;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF13110F)
          : const Color(0xFFF9F4EE),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background according to appearance settings
            if (appearance.fullPlayerBackground !=
                PlaybackBackgroundMode.solidColor) ...[
              PlaybackBackground(
                mode: appearance.fullPlayerBackground,
                albumPath: playback.artworkPath,
                artist: creditedArtist,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? const Color(0xFF13110F)
                              : const Color(0xFFF9F4EE))
                          .withValues(alpha: 0.88),
                ),
              ),
            ],

            // Main Editorial Stage Content
            Column(
              children: [
                // Top Stage Navigation & Environment Bar
                if (showTopBar)
                  _EditorialTopBar(
                    palette: palette,
                    appearance: appearance,
                    isDark: isDark,
                    stageMode: stageMode,
                    coverMode: coverMode,
                    embedded: embedded,
                  ),

                // Stage Body
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    child: switch (stageMode) {
                      PlaybackStageMode.splitStage => _SplitStage(
                        key: const ValueKey('split-stage'),
                        playback: playback,
                        track: track,
                        coverMode: coverMode,
                        palette: palette,
                        isDark: isDark,
                      ),
                      PlaybackStageMode.visualArt => _VisualArtStage(
                        key: const ValueKey('visual-art-stage'),
                        playback: playback,
                        track: track,
                        coverMode: coverMode,
                        palette: palette,
                        isDark: isDark,
                      ),
                      PlaybackStageMode.pureLyrics => Padding(
                        key: const ValueKey('pure-lyrics-stage'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 780),
                            child: const EditorialLyricsPanel(
                              isFullWidth: true,
                            ),
                          ),
                        ),
                      ),
                      PlaybackStageMode.editorialFocus => _EditorialFocusStage(
                        key: const ValueKey('editorial-focus-stage'),
                        playback: playback,
                        track: track,
                        palette: palette,
                        isDark: isDark,
                      ),
                    },
                  ),
                ),

                // Bottom Transport & Player Bar
                _EditorialPlayerBar(
                  playback: playback,
                  palette: palette,
                  isDark: isDark,
                ),
              ],
            ),

            // Floating "Show Controls" button when top bar is hidden
            if (!showTopBar)
              Positioned(
                top: 10,
                right: 16,
                child: InkWell(
                  onTap: () => ref
                      .read(editorialShowTopBarProvider.notifier)
                      .setShow(true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? const Color(0xFF221F1C)
                                  : const Color(0xFFEDE7DE))
                              .withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.hairline),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.expand_more, size: 14, color: palette.ink),
                        const SizedBox(width: 4),
                        Text(
                          'Show Controls',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorialTopBar extends ConsumerWidget {
  const _EditorialTopBar({
    required this.palette,
    required this.appearance,
    required this.isDark,
    required this.stageMode,
    required this.coverMode,
    required this.embedded,
  });

  final StudioPalette palette;
  final AppearanceState appearance;
  final bool isDark;
  final PlaybackStageMode stageMode;
  final PlaybackCoverMode coverMode;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 960;
          final isVeryCompact = constraints.maxWidth < 750;

          return Row(
            children: [
              // Exit / Back to Library
              if (!embedded) ...[
                TextButton.icon(
                  onPressed: ref.read(playbackModeProvider.notifier).exit,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.ink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text(
                    'Library',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                _VerticalDivider(color: palette.hairline),
                const SizedBox(width: 8),
              ],

              // Switcher pills scroll horizontally if tight, allowing action buttons to remain on screen
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stage Mode segmented switcher
                      if (!isCompact) ...[
                        Text(
                          'Stage:',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _SegmentedModePill<PlaybackStageMode>(
                        items: PlaybackStageMode.values,
                        selected: stageMode,
                        labelOf: (m) => isCompact ? m.shortLabel : m.label,
                        onSelected: (m) => ref
                            .read(editorialStageModeProvider.notifier)
                            .select(m),
                        palette: palette,
                      ),

                      if (!isVeryCompact) ...[
                        const SizedBox(width: 10),
                        if (!isCompact) ...[
                          Text(
                            'Cover Mode:',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        _SegmentedModePill<PlaybackCoverMode>(
                          items: PlaybackCoverMode.values,
                          selected: coverMode,
                          labelOf: (m) => m.label,
                          onSelected: (m) => ref
                              .read(editorialCoverModeProvider.notifier)
                              .select(m),
                          palette: palette,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Accent Pill (only if plenty of room)
              if (constraints.maxWidth > 1050) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.hairlineSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Accent: ',
                        style: TextStyle(fontSize: 11, color: palette.inkMuted),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Auto',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Dark / Light Theme Toggle
              IconButton(
                tooltip: isDark
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 18,
                  color: palette.ink,
                ),
                onPressed: () {
                  ref
                      .read(appearanceProvider.notifier)
                      .setThemeMode(
                        isDark ? AppThemeMode.light : AppThemeMode.dark,
                      );
                },
              ),

              // Audio Engine & DSP settings trigger
              IconButton(
                tooltip: 'Audio Engine & DSP Settings',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.graphic_eq, size: 18, color: palette.ink),
                onPressed: () => showAudioEngineSheet(context),
              ),

              // Full Player Menu (Customize background, etc.)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(iconTheme: IconThemeData(color: palette.ink)),
                child: FullPlayerMenu(appearance: appearance),
              ),

              // Hide Top Controls (Immersive Stage)
              IconButton(
                tooltip: 'Hide top controls',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.expand_less),
                color: palette.ink,
                onPressed: ref
                    .read(editorialShowTopBarProvider.notifier)
                    .toggle,
              ),

              // Fullscreen Exit
              if (!embedded)
                IconButton(
                  tooltip: 'Exit Playback Mode',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.fullscreen_exit),
                  color: palette.ink,
                  onPressed: ref.read(playbackModeProvider.notifier).exit,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SplitStage extends StatelessWidget {
  const _SplitStage({
    super.key,
    required this.playback,
    required this.track,
    required this.coverMode,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final Track? track;
  final PlaybackCoverMode coverMode;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 780;
        final isLowHeight = constraints.maxHeight < 560;

        if (isNarrow) {
          // Narrow viewport: Stack vertically with scroll
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: coverMode == PlaybackCoverMode.fullBleed ? 0 : 20,
              vertical: 16,
            ),
            child: Column(
              children: [
                if (coverMode == PlaybackCoverMode.fullBleed)
                  SizedBox(
                    width: double.infinity,
                    height: 280,
                    child: CoverArt(path: playback.artworkPath, size: 280),
                  )
                else
                  VinylSleeve(
                    artworkPath: playback.artworkPath,
                    size: 180,
                    coverMode: coverMode,
                    track: track,
                  ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _TrackHeader(
                        playback: playback,
                        palette: palette,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _AudiophileSpecsRow(playback: playback, palette: palette),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  height: 300,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: EditorialLyricsPanel(isFullWidth: true),
                  ),
                ),
              ],
            ),
          );
        }

        final leftWidth = (constraints.maxWidth * 0.46).clamp(360.0, 580.0);
        final sleeveSize = isLowHeight
            ? (constraints.maxHeight * 0.38).clamp(160.0, 240.0)
            : (constraints.maxHeight * 0.44).clamp(190.0, 310.0);

        return Row(
          children: [
            // Left Column: Vinyl Sleeve or Full Bleed Artwork & Track Metadata
            if (coverMode == PlaybackCoverMode.fullBleed)
              SizedBox(
                width: leftWidth,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full bleed cover art filling the column edge-to-edge
                    CoverArt(path: playback.artworkPath, size: leftWidth),
                    // Ambient gradient scrim for high readability
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 260,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark
                                      ? const Color(0xFF13110F)
                                      : const Color(0xFFF9F4EE))
                                  .withValues(alpha: 0.95),
                            ],
                            stops: const [0.0, 0.72],
                          ),
                        ),
                      ),
                    ),
                    // Metadata & actions anchored on top of gradient
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '— NOW PLAYING —',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playback.title.isEmpty
                                ? 'Untitled Track'
                                : playback.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spectral(
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _EditorialArtistAlbumByline(
                            playback: playback,
                            palette: palette,
                          ),
                          const SizedBox(height: 8),
                          _AudiophileSpecsRow(
                            playback: playback,
                            palette: palette,
                          ),
                          const SizedBox(height: 10),
                          _EditorialActionsRow(
                            playback: playback,
                            track: track,
                            palette: palette,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: leftWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Vinyl Sleeve
                      VinylSleeve(
                        artworkPath: playback.artworkPath,
                        size: sleeveSize,
                        coverMode: coverMode,
                        track: track,
                      ),
                      const SizedBox(height: 20),

                      // "— NOW PLAYING —" tracked micro-headline
                      Text(
                        '— NOW PLAYING —',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Track Title in Editorial Serif
                      Text(
                        playback.title.isEmpty
                            ? 'Untitled Track'
                            : playback.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spectral(
                          fontSize: sleeveSize > 230 ? 30 : 24,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Artist & Album Byline
                      _EditorialArtistAlbumByline(
                        playback: playback,
                        palette: palette,
                      ),
                      const SizedBox(height: 12),

                      // Audiophile Specs Badges
                      _AudiophileSpecsRow(playback: playback, palette: palette),
                      const SizedBox(height: 14),

                      // Actions Bar (Heart, Add to playlist, Booklet, Details, More)
                      _EditorialActionsRow(
                        playback: playback,
                        track: track,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
              ),

            // Hairline vertical divider separating the stage
            Container(
              width: 1,
              height: double.infinity,
              color: palette.hairline,
            ),

            // Right Column: Synchronized Editorial Lyrics
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                child: EditorialLyricsPanel(isFullWidth: false),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({
    required this.playback,
    required this.palette,
    required this.compact,
  });

  final PlaybackUiState playback;
  final StudioPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '— NOW PLAYING —',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w700,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          playback.title.isEmpty ? 'Untitled Track' : playback.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.spectral(
            fontSize: compact ? 22 : 30,
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 4),
        _EditorialArtistAlbumByline(playback: playback, palette: palette),
      ],
    );
  }
}

class _VisualArtStage extends StatelessWidget {
  const _VisualArtStage({
    super.key,
    required this.playback,
    required this.track,
    required this.coverMode,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final Track? track;
  final PlaybackCoverMode coverMode;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (coverMode == PlaybackCoverMode.fullBleed) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Full bleed backdrop cover art
              CoverArt(path: playback.artworkPath, size: constraints.maxWidth),
              // Soft gradient scrim towards bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        (isDark
                                ? const Color(0xFF13110F)
                                : const Color(0xFFF9F4EE))
                            .withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.72],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '— NOW PLAYING —',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playback.title.isEmpty
                          ? 'Untitled Track'
                          : playback.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spectral(
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _EditorialArtistAlbumByline(
                      playback: playback,
                      palette: palette,
                    ),
                    const SizedBox(height: 14),
                    _AudiophileSpecsRow(playback: playback, palette: palette),
                  ],
                ),
              ),
            ],
          );
        }

        final sleeveSize = (constraints.maxHeight * 0.52).clamp(200.0, 420.0);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VinylSleeve(
                  artworkPath: playback.artworkPath,
                  size: sleeveSize,
                  coverMode: coverMode,
                  track: track,
                ),
                const SizedBox(height: 24),
                Text(
                  '— NOW PLAYING —',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  playback.title.isEmpty ? 'Untitled Track' : playback.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spectral(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                _EditorialArtistAlbumByline(
                  playback: playback,
                  palette: palette,
                ),
                const SizedBox(height: 14),
                _AudiophileSpecsRow(playback: playback, palette: palette),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditorialFocusStage extends ConsumerWidget {
  const _EditorialFocusStage({
    super.key,
    required this.playback,
    required this.track,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final Track? track;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = playback.artist;
    final creditedArtist = artist == null
        ? null
        : LibraryQuery.creditedArtists(artist).firstOrNull;

    final values = discordTemplateValues(playback);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (creditedArtist != null) ...[
                    ArtistPortrait(artist: creditedArtist, size: 120),
                    const SizedBox(width: 24),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EDITORIAL LINER NOTES',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          playback.title,
                          style: GoogleFonts.spectral(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By ${playback.artist ?? "Unknown Artist"} · ${playback.album ?? "Unknown Album"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: palette.inkMuted,
                            fontFamilyFallback: const ['Georgia', 'serif'],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: palette.hairline),
              const SizedBox(height: 18),
              Text(
                'AUDIO SPECIFICATIONS & PROVENANCE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _SpecBlock(
                    label: 'Format',
                    value: values['format'] ?? 'Unknown',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Encoding',
                    value: values['lossless']?.isNotEmpty == true
                        ? 'Lossless Stream'
                        : 'Compressed',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Sample Rate',
                    value: values['sample_rate'] ?? '44.1 kHz',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Bitrate',
                    value: values['bitrate'] ?? 'Native',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Year',
                    value: values['year'] ?? 'Unknown',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Genre',
                    value: playback.genre ?? 'General',
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (playback.locator != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.hairlineSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 16,
                        color: palette.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playback.locator!,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.inkMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecBlock extends StatelessWidget {
  const _SpecBlock({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.hairlineSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: palette.inkMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialArtistAlbumByline extends ConsumerWidget {
  const _EditorialArtistAlbumByline({
    required this.playback,
    required this.palette,
  });

  final PlaybackUiState playback;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = playback.artist ?? 'Unknown Artist';
    final album = playback.album ?? '';
    final year = playback.year != null && playback.year! > 0
        ? ' (${playback.year})'
        : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(libraryNavigationProvider.notifier).openArtist(artist);
          ref.read(playbackModeProvider.notifier).exit();
          ref
              .read(studioNavProvider.notifier)
              .select(StudioDestination.library);
        },
        child: Text(
          album.isNotEmpty ? '$artist • $album$year' : artist,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: palette.inkMuted,
            fontFamilyFallback: const ['Georgia', 'serif'],
          ),
        ),
      ),
    );
  }
}

class _AudiophileSpecsRow extends StatelessWidget {
  const _AudiophileSpecsRow({required this.playback, required this.palette});

  final PlaybackUiState playback;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    final values = discordTemplateValues(playback);
    final format = values['format'] ?? '';
    final lossless = values['lossless'] ?? '';
    final sampleRate = values['sample_rate'] ?? '';

    final badges = [
      if (format.isNotEmpty)
        '$format ${lossless.isNotEmpty ? lossless : ""}'.trim(),
      if (sampleRate.isNotEmpty) sampleRate,
      'ReplayGain -1.2 dB',
      'Bit-Perfect Engine',
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in badges)
          InkWell(
            onTap: () => showAudioEngineSheet(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: palette.hairlineSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.hairline),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: palette.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditorialActionsRow extends ConsumerWidget {
  const _EditorialActionsRow({
    required this.playback,
    required this.track,
    required this.palette,
  });

  final PlaybackUiState playback;
  final Track? track;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Favorite / Heart
        IconButton(
          tooltip: 'Favorite',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.favorite_border, size: 18, color: palette.inkMuted),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added to Favorites: ${playback.title}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        // Add to Playlist
        if (track != null)
          IconButton(
            tooltip: 'Add to Playlist',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add, size: 20, color: palette.inkMuted),
            onPressed: () {
              showTrackActions(
                context: context,
                ref: ref,
                track: track!,
                position: const Offset(300, 300),
              );
            },
          ),
        // Liner notes / Editorial focus
        IconButton(
          tooltip: 'Liner Notes & Album Details',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.menu_book, size: 18, color: palette.inkMuted),
          onPressed: () {
            ref
                .read(editorialStageModeProvider.notifier)
                .select(PlaybackStageMode.editorialFocus);
          },
        ),
        // Track context menu
        if (track != null)
          TrackActionsButton(track: track!, color: palette.inkMuted),
      ],
    );
  }
}

class _EditorialScrubberWithHover extends StatefulWidget {
  const _EditorialScrubberWithHover({
    required this.playback,
    required this.palette,
    required this.isDark,
    required this.onSeek,
  });

  final PlaybackUiState playback;
  final StudioPalette palette;
  final bool isDark;
  final ValueChanged<double> onSeek;

  @override
  State<_EditorialScrubberWithHover> createState() =>
      _EditorialScrubberWithHoverState();
}

class _EditorialScrubberWithHoverState
    extends State<_EditorialScrubberWithHover> {
  double? _hoverFraction;
  double? _hoverDx;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.playback.duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (widget.playback.position.inMilliseconds / durationMs).clamp(
            0.0,
            1.0,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final hoverFraction = _hoverFraction;
        final hoverDx = _hoverDx;

        Duration? hoverTime;
        if (_isHovering && hoverFraction != null && durationMs > 0) {
          hoverTime = Duration(
            milliseconds: (durationMs * hoverFraction).round(),
          );
        }

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (e) {
            setState(() {
              _isHovering = true;
              _hoverDx = e.localPosition.dx;
              _hoverFraction = (e.localPosition.dx / totalWidth).clamp(
                0.0,
                1.0,
              );
            });
          },
          onHover: (e) {
            setState(() {
              _isHovering = true;
              _hoverDx = e.localPosition.dx;
              _hoverFraction = (e.localPosition.dx / totalWidth).clamp(
                0.0,
                1.0,
              );
            });
          },
          onExit: (_) {
            setState(() {
              _isHovering = false;
              _hoverFraction = null;
              _hoverDx = null;
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Edge-to-edge Scrubber Slider
              SizedBox(
                height: 14,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor: widget.palette.accent,
                    inactiveTrackColor: widget.palette.hairline,
                    thumbColor: widget.palette.accent,
                    overlayColor: widget.palette.accent.withValues(alpha: 0.15),
                  ),
                  child: Slider(value: progress, onChanged: widget.onSeek),
                ),
              ),

              // Hover hairline cursor indicator
              if (_isHovering && hoverDx != null)
                Positioned(
                  left: hoverDx.clamp(0.0, totalWidth - 1),
                  top: 2,
                  bottom: 2,
                  child: IgnorePointer(
                    child: Container(
                      width: 1.5,
                      color: widget.palette.accent.withValues(alpha: 0.75),
                    ),
                  ),
                ),

              // Hover floating time chip
              if (hoverTime != null && hoverDx != null)
                Positioned(
                  left: (hoverDx - 22).clamp(
                    8.0,
                    (totalWidth - 52).clamp(8.0, double.infinity),
                  ),
                  bottom: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF221F1C)
                            : const Color(0xFF1E1C1A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: widget.palette.accent.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        formatDuration(hoverTime),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
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

class _EditorialPlayerBar extends ConsumerWidget {
  const _EditorialPlayerBar({
    required this.playback,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackControllerProvider.notifier);
    final showTopBar = ref.watch(editorialShowTopBarProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161412) : const Color(0xFFF6F1EA),
        border: Border(top: BorderSide(color: palette.hairline, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edge-to-edge Scrubber Slider with Hover Timestamp
          _EditorialScrubberWithHover(
            playback: playback,
            palette: palette,
            isDark: isDark,
            onSeek: controller.seekFraction,
          ),

          // Transport controls row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                final isVeryNarrow = constraints.maxWidth < 540;
                final volumeWidth = constraints.maxWidth > 950
                    ? 140.0
                    : (isNarrow ? 90.0 : 120.0);

                return Row(
                  children: [
                    // Left: Mini artwork & title
                    SizedBox(
                      width: isVeryNarrow ? 100 : (isNarrow ? 130 : 190),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: CoverArt(
                              path: playback.artworkPath,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  playback.title.isEmpty
                                      ? 'Nothing Playing'
                                      : playback.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.ink,
                                  ),
                                ),
                                Text(
                                  playback.artist ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Center: Playback Controls (Clean & free of DSP clutter!)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isNarrow)
                          IconButton(
                            tooltip: 'Shuffle',
                            visualDensity: VisualDensity.compact,
                            onPressed: controller.toggleShuffle,
                            color: playback.shuffle
                                ? palette.accent
                                : palette.inkMuted,
                            icon: const Icon(Icons.shuffle, size: 18),
                          ),
                        IconButton(
                          tooltip: 'Previous Track',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.skipPrevious,
                          color: palette.ink,
                          icon: const Icon(Icons.skip_previous, size: 20),
                        ),
                        const SizedBox(width: 2),
                        // Circular filled Play/Pause button
                        IconButton.filled(
                          tooltip: playback.playing ? 'Pause' : 'Play',
                          onPressed: controller.togglePlayPause,
                          style: IconButton.styleFrom(
                            backgroundColor: palette.ink,
                            foregroundColor: palette.bg,
                            minimumSize: const Size(40, 40),
                          ),
                          icon: Icon(
                            playback.playing ? Icons.pause : Icons.play_arrow,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: 'Next Track',
                          visualDensity: VisualDensity.compact,
                          onPressed: controller.skipNext,
                          color: palette.ink,
                          icon: const Icon(Icons.skip_next, size: 20),
                        ),
                        if (!isNarrow)
                          IconButton(
                            tooltip: 'Repeat',
                            visualDensity: VisualDensity.compact,
                            onPressed: controller.cycleRepeat,
                            color: playback.repeat == QueueRepeatMode.off
                                ? palette.inkMuted
                                : palette.accent,
                            icon: Icon(
                              playback.repeat == QueueRepeatMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              size: 18,
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Right: Time, DSP Badge, Volume, and Top Bar Unhide
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${formatDuration(playback.position)} / ${formatDuration(playback.duration)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.inkMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Relocated DSP Badge (Away from center playback controls!)
                        InkWell(
                          onTap: () => showAudioEngineSheet(context),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.hairlineSoft,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: palette.hairline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.graphic_eq,
                                  size: 12,
                                  color: palette.accent,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'DSP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: palette.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (!isNarrow) ...[
                          const SizedBox(width: 8),
                          // Volume Icon & Slider (Longer for precision control)
                          Icon(
                            playback.volume <= 0
                                ? Icons.volume_off
                                : playback.volume < 0.5
                                ? Icons.volume_down
                                : Icons.volume_up,
                            size: 16,
                            color: palette.inkMuted,
                          ),
                          SizedBox(
                            width: volumeWidth,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 4,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 8,
                                ),
                                activeTrackColor: palette.ink,
                                inactiveTrackColor: palette.hairline,
                                thumbColor: palette.ink,
                              ),
                              child: Slider(
                                value: playback.volume.clamp(0.0, 1.0),
                                onChanged: controller.setVolume,
                              ),
                            ),
                          ),
                        ],

                        if (!showTopBar) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Show top controls',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.tune, size: 16),
                            color: palette.accent,
                            onPressed: () => ref
                                .read(editorialShowTopBarProvider.notifier)
                                .setShow(true),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedModePill<T> extends StatelessWidget {
  const _SegmentedModePill({
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    required this.palette,
  });

  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.hairlineSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.hairline),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items) ...[
            GestureDetector(
              onTap: () => onSelected(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: item == selected ? palette.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: item == selected
                      ? Border.all(color: palette.accent.withValues(alpha: 0.5))
                      : null,
                  boxShadow: item == selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labelOf(item),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: item == selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: item == selected ? palette.ink : palette.inkMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 16, color: color);
  }
}
