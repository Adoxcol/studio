import 'package:flutter/material.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

/// The canonical compact presentation for a track in any queue surface.
class QueueTrackRow extends StatelessWidget {
  const QueueTrackRow({
    super.key,
    required this.track,
    this.current = false,
    this.onTap,
    this.onMenu,
    this.onRemove,
    this.dragHandle,
  });

  static const double height = 64;
  static const double artworkSize = 40;

  final Track? track;
  final bool current;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onMenu;
  final VoidCallback? onRemove;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final title = track?.title ?? 'Unknown track';
    final rawArtist = track?.artist?.trim();
    final artist = rawArtist == null || rawArtist.isEmpty
        ? 'Unknown artist'
        : rawArtist;
    final duration = formatDurationMs(track?.durationMs);

    return Semantics(
      button: onTap != null,
      selected: current,
      label: '$title, $artist${duration.isEmpty ? '' : ', $duration'}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onSecondaryTapUp: onMenu == null
              ? null
              : (details) => onMenu!(details.globalPosition),
          mouseCursor: onTap == null
              ? MouseCursor.defer
              : SystemMouseCursors.click,
          hoverColor: palette.hairlineSoft,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: CoverArt(
                      path: track?.artworkPath,
                      size: artworkSize,
                    ),
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
                              ?.copyWith(
                                color: current ? palette.accent : palette.ink,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text(
                      duration,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (onMenu != null)
                    Builder(
                      builder: (buttonContext) => IconButton(
                        tooltip: 'Track actions',
                        onPressed: () {
                          final box =
                              buttonContext.findRenderObject()! as RenderBox;
                          final origin = box.localToGlobal(Offset.zero);
                          onMenu!(
                            Offset(
                              origin.dx + box.size.width,
                              origin.dy + box.size.height,
                            ),
                          );
                        },
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.more_horiz,
                          size: 19,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'Remove from queue',
                      onPressed: onRemove,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close,
                        size: 17,
                        color: palette.inkMuted,
                      ),
                    ),
                  if (dragHandle != null) ...[
                    const SizedBox(width: 4),
                    dragHandle!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
