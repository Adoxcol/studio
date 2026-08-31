import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

class LibraryTrackTable extends ConsumerWidget {
  const LibraryTrackTable({
    super.key,
    required this.tracks,
    required this.onPlay,
    this.onTrackMenu,
    this.bottomInset = 0,
  });

  static const double rowExtent = 45;
  static const double cardExtent = 72;
  static const double coverSize = 56;

  final List<Track> tracks;
  final void Function(int index) onPlay;
  final void Function(Track track, Offset globalPosition)? onTrackMenu;

  /// Extra scrollable space so floating navigation never traps the final row.
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final playingId = ref.watch(
      playbackControllerProvider.select((s) => s.trackId),
    );
    if (appearance.trackLayout == TrackLayout.cards) {
      return _TrackCardGrid(
        tracks: tracks,
        playingId: playingId,
        showArtwork: appearance.showTrackArtwork,
        onPlay: onPlay,
        onTrackMenu: onTrackMenu,
        bottomInset: bottomInset,
      );
    }
    return _TrackList(
      tracks: tracks,
      playingId: playingId,
      showArtwork: appearance.showTrackArtwork,
      onPlay: onPlay,
      onTrackMenu: onTrackMenu,
      bottomInset: bottomInset,
    );
  }
}

class _TrackCardGrid extends StatelessWidget {
  const _TrackCardGrid({
    required this.tracks,
    required this.playingId,
    required this.showArtwork,
    required this.onPlay,
    required this.bottomInset,
    this.onTrackMenu,
  });

  final List<Track> tracks;
  final int? playingId;
  final bool showArtwork;
  final double bottomInset;
  final void Function(int index) onPlay;
  final void Function(Track track, Offset globalPosition)? onTrackMenu;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 16 + bottomInset),
      addAutomaticKeepAlives: false,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: LibraryTrackTable.cardExtent,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _TrackCard(
          key: ValueKey(track.id),
          track: track,
          playing: track.id == playingId,
          showArtwork: showArtwork,
          onPlay: () => onPlay(index),
          onMenu: onTrackMenu == null
              ? null
              : (offset) => onTrackMenu!(track, offset),
        );
      },
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    super.key,
    required this.track,
    required this.playing,
    required this.showArtwork,
    required this.onPlay,
    this.onMenu,
  });

  final Track track;
  final bool playing;
  final bool showArtwork;
  final VoidCallback onPlay;
  final ValueChanged<Offset>? onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted, height: 1.25);
    final caption = LibraryQuery.albumCaption(track);
    final duration = formatDurationMs(track.durationMs);
    final semanticLabel =
        '${track.title}, '
        '${track.artist ?? "Unknown artist"}'
        '${duration.isEmpty ? "" : ", $duration"}';

    return Semantics(
      button: true,
      selected: playing,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPlay,
        onSecondaryTapUp: onMenu == null
            ? null
            : (details) => onMenu!(details.globalPosition),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: palette.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  if (showArtwork) ...[
                    CoverArt(
                      path: track.artworkPath,
                      size: LibraryTrackTable.coverSize,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: playing ? palette.accent : palette.ink,
                              ),
                        ),
                        if (track.artist != null && track.artist!.isNotEmpty)
                          Text(
                            track.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.playingId,
    required this.showArtwork,
    required this.onPlay,
    required this.bottomInset,
    this.onTrackMenu,
  });

  final List<Track> tracks;
  final int? playingId;
  final bool showArtwork;
  final double bottomInset;
  final void Function(int index) onPlay;
  final void Function(Track track, Offset globalPosition)? onTrackMenu;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: _ColumnHeaders(),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: bottomInset),
            itemExtent: LibraryTrackTable.rowExtent,
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
                  showArtwork: showArtwork,
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
    required this.showArtwork,
    required this.onPlay,
    this.onMenu,
  });

  final Track track;
  final bool playing;
  final bool showArtwork;
  final VoidCallback onPlay;
  final ValueChanged<Offset>? onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted);
    final duration = formatDurationMs(track.durationMs);
    final semanticLabel =
        '${track.title}, '
        '${track.artist ?? "Unknown artist"}'
        '${duration.isEmpty ? "" : ", $duration"}';

    return Semantics(
      button: true,
      selected: playing,
      label: semanticLabel,
      child: GestureDetector(
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
                if (showArtwork) ...[
                  CoverArt(path: track.artworkPath, size: 28),
                  const SizedBox(width: 8),
                ],
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
      ),
    );
  }
}
