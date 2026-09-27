import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/mini_player/presentation/mini_player_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:window_manager/window_manager.dart';

/// Compact always-available player shown while the window is shrunk.
class MiniPlayerView extends ConsumerWidget {
  const MiniPlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final track = ref.watch(
      playbackControllerProvider.select(
        (s) => (
          title: s.title,
          artist: s.artist,
          artwork: s.artworkPath,
          playing: s.playing,
          hasTrack: s.trackId != null,
        ),
      ),
    );
    final progress = ref.watch(
      playbackControllerProvider.select((s) => s.progress),
    );
    final mini = ref.watch(miniPlayerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);
    final notifier = ref.read(miniPlayerProvider.notifier);

    return Material(
      color: palette.bg,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DragToMoveArea(child: SizedBox.expand()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                  child: Row(
                    children: [
                      CoverArt(path: track.artwork, size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IgnorePointer(
                              child: Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: palette.ink),
                              ),
                            ),
                            if (track.artist != null)
                              IgnorePointer(
                                child: Text(
                                  track.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: palette.inkMuted),
                                ),
                              ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MiniButton(
                                  icon: Icons.skip_previous,
                                  tooltip: 'Previous',
                                  onTap: track.hasTrack
                                      ? () =>
                                            unawaited(controller.skipPrevious())
                                      : null,
                                ),
                                _MiniButton(
                                  icon: track.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  tooltip: track.playing ? 'Pause' : 'Play',
                                  onTap: track.hasTrack
                                      ? () => unawaited(
                                          controller.togglePlayPause(),
                                        )
                                      : null,
                                ),
                                _MiniButton(
                                  icon: Icons.skip_next,
                                  tooltip: 'Next',
                                  onTap: track.hasTrack
                                      ? () => unawaited(controller.skipNext())
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniButton(
                            icon: mini.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            tooltip: mini.pinned
                                ? 'Stop keeping on top'
                                : 'Keep on top',
                            selected: mini.pinned,
                            onTap: () => unawaited(notifier.togglePinned()),
                          ),
                          _MiniButton(
                            icon: Icons.open_in_full,
                            tooltip: 'Back to full player',
                            onTap: () => unawaited(notifier.exit()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: track.hasTrack ? progress : 0,
            minHeight: 2,
            color: palette.accent,
            backgroundColor: palette.hairline,
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      isSelected: selected,
      icon: Icon(
        icon,
        color: onTap == null
            ? palette.inkMuted.withAlpha(120)
            : selected
            ? palette.accent
            : palette.ink,
      ),
    );
  }
}
