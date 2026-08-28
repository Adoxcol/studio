import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class LibraryTrackTable extends ConsumerWidget {
  const LibraryTrackTable({
    super.key,
    required this.tracks,
    required this.onPlay,
    this.onTrackMenu,
  });

  static const double rowExtent = 45;

  final List<Track> tracks;
  final void Function(int index) onPlay;
  final void Function(Track track, Offset globalPosition)? onTrackMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final playingId = ref.watch(
      playbackControllerProvider.select((s) => s.trackId),
    );
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: _ColumnHeaders(),
        ),
        Expanded(
          child: ListView.builder(
            itemExtent: rowExtent,
            addAutomaticKeepAlives: false,
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return DecoratedBox(
                key: ValueKey(track.id),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: palette.hairlineSoft),
                  ),
                ),
                child: _TrackRow(
                  track: track,
                  playing: track.id == playingId,
                  onPlay: () => onPlay(index),
                  onMenu: onTrackMenu == null
                      ? null
                      : (offset) => onTrackMenu!(track, offset),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: palette.inkMuted,
      letterSpacing: 1.2,
      fontSize: 11,
    );
    return Row(
      children: [
        const SizedBox(width: 28),
        Expanded(flex: 3, child: Text('TITLE', style: style)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: Text('ARTIST', style: style)),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: Text('ALBUM', style: style)),
        const SizedBox(width: 16),
        SizedBox(
          width: 52,
          child: Text('TIME', style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.playing,
    required this.onPlay,
    this.onMenu,
  });

  final Track track;
  final bool playing;
  final VoidCallback onPlay;
  final ValueChanged<Offset>? onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted);
    return GestureDetector(
      onTap: onPlay,
      onSecondaryTapUp: onMenu == null
          ? null
          : (details) => onMenu!(details.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          height: LibraryTrackTable.rowExtent - 1,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: playing
                    ? Icon(Icons.graphic_eq, size: 16, color: palette.accent)
                    : Text(track.trackNumber?.toString() ?? '', style: muted),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: playing ? palette.accent : palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  track.artist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                  track.album ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 52,
                child: Text(
                  formatDurationMs(track.durationMs),
                  maxLines: 1,
                  textAlign: TextAlign.right,
                  style: muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
