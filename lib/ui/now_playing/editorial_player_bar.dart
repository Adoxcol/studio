part of 'editorial_stage.dart';

/// Watches the position itself so only the scrubber redraws on every tick.
class _EditorialScrubberWithHover extends ConsumerStatefulWidget {
  const _EditorialScrubberWithHover({
    required this.palette,
    required this.isDark,
    required this.onSeek,
  });

  final StudioPalette palette;
  final bool isDark;
  final ValueChanged<double> onSeek;

  @override
  ConsumerState<_EditorialScrubberWithHover> createState() =>
      _EditorialScrubberWithHoverState();
}

class _EditorialScrubberWithHoverState
    extends ConsumerState<_EditorialScrubberWithHover> {
  double? _hoverFraction;
  double? _hoverDx;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final (position, duration) = ref.watch(
      playbackControllerProvider.select((s) => (s.position, s.duration)),
    );
    final durationMs = duration.inMilliseconds;
    final progress = durationMs <= 0
        ? 0.0
        : (position.inMilliseconds / durationMs).clamp(0.0, 1.0);

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
                        Consumer(
                          builder: (context, ref, _) {
                            final (position, duration) = ref.watch(
                              playbackControllerProvider.select(
                                (s) => (s.position, s.duration),
                              ),
                            );
                            return Text(
                              '${formatDuration(position)} / ${formatDuration(duration)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: palette.inkMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            );
                          },
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
