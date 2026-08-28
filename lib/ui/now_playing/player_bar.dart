import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

class PlayerBar extends ConsumerWidget {
  const PlayerBar({super.key});

  static const double scrubberHeight = 20;
  static const double contentHeight = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final playback = ref.watch(playbackControllerProvider);
    final remaining = playback.duration - playback.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DividerScrubber(
          progress: playback.progress,
          elapsedLabel: formatDuration(playback.position),
          remainingLabel: formatDuration(remaining),
          onSeek: (fraction) {
            ref
                .read(playbackControllerProvider.notifier)
                .seekFraction(fraction);
          },
        ),
        SizedBox(
          height: contentHeight,
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: palette.ink),
                            ),
                            if (playback.artist != null)
                              Text(
                                playback.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.inkMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _Transport(playback: playback),
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
        ),
      ],
    );
  }
}

class _DividerScrubber extends StatelessWidget {
  const _DividerScrubber({
    required this.progress,
    required this.elapsedLabel,
    required this.remainingLabel,
    required this.onSeek,
  });

  final double progress;
  final String elapsedLabel;
  final String remainingLabel;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return SizedBox(
      height: PlayerBar.scrubberHeight,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              onSeek(details.localPosition.dx / constraints.maxWidth);
            },
            onHorizontalDragUpdate: (details) {
              onSeek(details.localPosition.dx / constraints.maxWidth);
            },
            child: Stack(
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        elapsedLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.inkMuted,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        remainingLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.inkMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Transport extends ConsumerWidget {
  const _Transport({required this.playback});

  final PlaybackUiState playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final controller = ref.read(playbackControllerProvider.notifier);

    Widget button({
      required IconData icon,
      required VoidCallback onTap,
      Color? color,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(icon, size: 20, color: color ?? palette.ink),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          icon: Icons.shuffle,
          onTap: controller.toggleShuffle,
          color: playback.shuffle ? palette.accent : palette.ink,
        ),
        button(icon: Icons.skip_previous, onTap: controller.skipPrevious),
        button(
          icon: playback.playing ? Icons.pause : Icons.play_arrow,
          onTap: controller.togglePlayPause,
        ),
        button(icon: Icons.skip_next, onTap: controller.skipNext),
        button(
          icon: playback.repeat == QueueRepeatMode.one
              ? Icons.repeat_one
              : Icons.repeat,
          onTap: controller.cycleRepeat,
          color: playback.repeat == QueueRepeatMode.off
              ? palette.ink
              : palette.accent,
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
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  onChanged(details.localPosition.dx / constraints.maxWidth);
                },
                onHorizontalDragUpdate: (details) {
                  onChanged(details.localPosition.dx / constraints.maxWidth);
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
              );
            },
          ),
        ),
      ],
    );
  }
}
