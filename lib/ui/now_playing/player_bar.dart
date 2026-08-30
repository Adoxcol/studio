import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  static const double scrubberHeight = 20;
  static const double contentHeight = 64;

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [_PlayerBarScrubber(), _PlayerBarBody()],
    );
  }
}

class _PlayerBarScrubber extends ConsumerWidget {
  const _PlayerBarScrubber();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      playbackControllerProvider.select(
        (s) => (position: s.position, duration: s.duration),
      ),
    );
    return _DividerScrubber(
      progress: snapshot.duration.inMilliseconds <= 0
          ? 0
          : (snapshot.position.inMilliseconds /
                  snapshot.duration.inMilliseconds)
              .clamp(0.0, 1.0),
      duration: snapshot.duration,
      onSeek: (fraction) {
        ref.read(playbackControllerProvider.notifier).seekFraction(fraction);
      },
      onScrubStart: () {
        ref.read(playbackControllerProvider.notifier).beginScrub();
      },
      onScrubEnd: () {
        ref.read(playbackControllerProvider.notifier).endScrub();
      },
    );
  }
}

class _PlayerBarBody extends ConsumerWidget {
  const _PlayerBarBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final playback = ref.watch(
      playbackControllerProvider.select(
        (s) => (
          title: s.title,
          artist: s.artist,
          artworkPath: s.artworkPath,
          playing: s.playing,
          volume: s.volume,
          shuffle: s.shuffle,
          repeat: s.repeat,
        ),
      ),
    );

    return SizedBox(
      height: PlayerBar.contentHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: Row(
                children: [
                  CoverArt(path: playback.artworkPath, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playback.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: palette.ink),
                        ),
                        if (playback.artist != null)
                          Text(
                            playback.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: palette.inkMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _Transport(
              playing: playback.playing,
              shuffle: playback.shuffle,
              repeat: playback.repeat,
            ),
            const Spacer(),
            SizedBox(
              width: 130,
              child: _VolumeCluster(
                volume: playback.volume,
                onChanged: (value) {
                  ref
                      .read(playbackControllerProvider.notifier)
                      .setVolume(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DividerScrubber extends StatefulWidget {
  const _DividerScrubber({
    required this.progress,
    required this.duration,
    required this.onSeek,
    required this.onScrubStart,
    required this.onScrubEnd,
  });

  final double progress;
  final Duration duration;
  final ValueChanged<double> onSeek;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;

  @override
  State<_DividerScrubber> createState() => _DividerScrubberState();
}

class _DividerScrubberState extends State<_DividerScrubber> {
  double? _scrub;
  double? _sent;
  var _hover = false;

  double get _shown => (_scrub ?? widget.progress).clamp(0.0, 1.0);

  bool get _showTimes =>
      (_hover || _scrub != null) && widget.duration > Duration.zero;

  double _fraction(Offset local, double width) {
    if (width <= 0) return 0;
    return (local.dx / width).clamp(0.0, 1.0);
  }

  void _send(double value) {
    if (_sent != null && (value - _sent!).abs() < 0.003) return;
    _sent = value;
    widget.onSeek(value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final progress = _shown;
    final elapsed = Duration(
      milliseconds: (widget.duration.inMilliseconds * progress).round(),
    );
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: palette.inkMuted, fontSize: 11);
    final currentStyle = style?.copyWith(color: palette.ink);
    return SizedBox(
      height: PlayerBar.scrubberHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                widget.onScrubStart();
                final value = _fraction(
                  event.localPosition,
                  constraints.maxWidth,
                );
                setState(() => _scrub = value);
                _send(value);
              },
              onPointerMove: (event) {
                if (_scrub == null || !event.down) return;
                setState(
                  () => _scrub = _fraction(
                    event.localPosition,
                    constraints.maxWidth,
                  ),
                );
              },
              onPointerUp: (_) {
                final value = _scrub;
                if (value != null) _send(value);
                widget.onScrubEnd();
                _sent = null;
                setState(() => _scrub = null);
              },
              onPointerCancel: (_) {
                widget.onScrubEnd();
                _sent = null;
                setState(() => _scrub = null);
              },
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Align(
                    child: Container(height: 2, color: palette.hairlineStrong),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(height: 2, color: palette.accent),
                    ),
                  ),
                  Align(
                    alignment: Alignment(progress * 2 - 1, 0),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: palette.ink.withValues(alpha: 0.18),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showTimes)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: IgnorePointer(
                        child: _HoverTimes(
                          start: formatDuration(Duration.zero),
                          current: formatDuration(elapsed),
                          end: formatDuration(widget.duration),
                          progress: progress,
                          startStyle: style,
                          currentStyle: currentStyle,
                          background: palette.bg,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HoverTimes extends StatelessWidget {
  const _HoverTimes({
    required this.start,
    required this.current,
    required this.end,
    required this.progress,
    required this.startStyle,
    required this.currentStyle,
    required this.background,
  });

  final String start;
  final String current;
  final String end;
  final double progress;
  final TextStyle? startStyle;
  final TextStyle? currentStyle;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final nearStart = progress < 0.08;
    final nearEnd = progress > 0.92;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!nearStart)
          Align(
            alignment: Alignment.centerLeft,
            child: _TimeChip(
              text: start,
              style: startStyle,
              background: background,
            ),
          ),
        Align(
          alignment: Alignment(progress * 2 - 1, 0),
          child: _TimeChip(
            text: current,
            style: currentStyle,
            background: background,
          ),
        ),
        if (!nearEnd)
          Align(
            alignment: Alignment.centerRight,
            child: _TimeChip(
              text: end,
              style: startStyle,
              background: background,
            ),
          ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.text,
    required this.style,
    required this.background,
  });

  final String text;
  final TextStyle? style;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(text, style: style),
      ),
    );
  }
}

class _Transport extends ConsumerWidget {
  const _Transport({
    required this.playing,
    required this.shuffle,
    required this.repeat,
  });

  final bool playing;
  final bool shuffle;
  final QueueRepeatMode repeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final controller = ref.read(playbackControllerProvider.notifier);

    Widget button({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      Color? color,
    }) {
      return Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              height: PlayerBar.contentHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon, size: 20, color: color ?? palette.ink),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          icon: Icons.shuffle,
          tooltip: 'Shuffle',
          onTap: controller.toggleShuffle,
          color: shuffle ? palette.accent : palette.ink,
        ),
        button(
          icon: Icons.skip_previous,
          tooltip: 'Previous',
          onTap: controller.skipPrevious,
        ),
        button(
          icon: playing ? Icons.pause : Icons.play_arrow,
          tooltip: playing ? 'Pause' : 'Play',
          onTap: controller.togglePlayPause,
        ),
        button(
          icon: Icons.skip_next,
          tooltip: 'Next',
          onTap: controller.skipNext,
        ),
        button(
          icon: repeat == QueueRepeatMode.one ? Icons.repeat_one : Icons.repeat,
          tooltip: 'Repeat',
          onTap: controller.cycleRepeat,
          color: repeat == QueueRepeatMode.off ? palette.ink : palette.accent,
        ),
      ],
    );
  }
}

class _VolumeCluster extends StatelessWidget {
  const _VolumeCluster({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Row(
      children: [
        Icon(Icons.volume_up, size: 16, color: palette.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    onChanged(
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      ),
                    );
                  },
                  onHorizontalDragStart: (details) {
                    onChanged(
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      ),
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    onChanged(
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      ),
                    );
                  },
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(height: 2, color: palette.hairlineStrong),
                        FractionallySizedBox(
                          widthFactor: volume,
                          child: Container(height: 2, color: palette.accent),
                        ),
                        Align(
                          alignment: Alignment(volume * 2 - 1, 0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
