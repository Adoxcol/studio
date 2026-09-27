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

part 'editorial_stage_layouts.dart';
part 'editorial_stage_details.dart';
part 'editorial_player_bar.dart';

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
    final playback = ref.watch(playbackWithoutPositionProvider);
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
