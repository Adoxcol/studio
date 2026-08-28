import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

/// Persistent footer: 20px edge-to-edge divider-scrubber, then a 64px row.
class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    this.progress = 0,
    this.title = 'Not playing',
    this.artist,
    this.elapsedLabel = '0:00',
    this.remainingLabel = '0:00',
  });

  final double progress;
  final String title;
  final String? artist;
  final String elapsedLabel;
  final String remainingLabel;

  static const double scrubberHeight = 20;
  static const double contentHeight = 64;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DividerScrubber(
          progress: progress.clamp(0.0, 1.0),
          elapsedLabel: elapsedLabel,
          remainingLabel: remainingLabel,
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
                      Container(
                        width: 40,
                        height: 40,
                        color: palette.artSwatch,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: palette.ink),
                            ),
                            if (artist != null)
                              Text(
                                artist!,
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
                const _Transport(),
                const Spacer(),
                const SizedBox(width: 130, child: _VolumeCluster()),
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
  });

  final double progress;
  final String elapsedLabel;
  final String remainingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return SizedBox(
      height: PlayerBar.scrubberHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Align(child: Container(height: 2, color: palette.hairlineStrong)),
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
  }
}

class _Transport extends StatelessWidget {
  const _Transport();

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    Widget button(IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(icon, size: 20, color: palette.ink),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.shuffle),
        button(Icons.skip_previous),
        button(Icons.play_arrow),
        button(Icons.skip_next),
        button(Icons.repeat),
      ],
    );
  }
}

class _VolumeCluster extends StatelessWidget {
  const _VolumeCluster();

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Row(
      children: [
        Icon(Icons.volume_up, size: 16, color: palette.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 10,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 2, color: palette.hairlineStrong),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(height: 2, color: palette.accent),
                ),
                Align(
                  alignment: const Alignment(0.4, 0),
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
      ],
    );
  }
}
