import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/visualizer/amplitude_visualizer.dart';

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  static const double artSize = 280;
  static const double upNextWidth = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackControllerProvider);
    final tracks = ref.watch(libraryTracksProvider).value ?? const [];
    final byId = {for (final track in tracks) track.id: track};

    return LayoutBuilder(
      builder: (context, constraints) {
        final showUpNext = constraints.maxWidth >= 800;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Hero(
                title: playback.title,
                artist: playback.artist,
                artworkPath: playback.artworkPath,
                hasTrack: playback.trackId != null,
                playing: playback.playing,
                position: playback.position,
              ),
            ),
            if (showUpNext)
              _UpNext(
                upcoming: [
                  for (final id in playback.upcomingIds)
                    if (byId[id] != null) byId[id]!,
                ],
                onSelect: (track) {
                  final index = playback.queueIds.indexOf(track.id);
                  ref
                      .read(playbackControllerProvider.notifier)
                      .playQueueIndex(index);
                },
              ),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.artist,
    required this.artworkPath,
    required this.hasTrack,
    required this.playing,
    required this.position,
  });

  final String title;
  final String? artist;
  final String? artworkPath;
  final bool hasTrack;
  final bool playing;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = [
          NowPlayingPage.artSize,
          (constraints.maxWidth - 64).clamp(96.0, NowPlayingPage.artSize),
          (constraints.maxHeight * 0.42).clamp(96.0, NowPlayingPage.artSize),
        ].reduce((a, b) => a < b ? a : b);
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CoverArt(path: artworkPath, size: artSize),
                    const SizedBox(height: 16),
                    AmplitudeVisualizer(
                      playing: playing,
                      position: position,
                      width: artSize,
                    ),
                    const SizedBox(height: 24),
                    if (hasTrack)
                      Text(
                        'now playing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.inkMutedAlt,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (hasTrack) const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (artist != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        artist!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.inkMuted,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UpNext extends StatelessWidget {
  const _UpNext({required this.upcoming, required this.onSelect});

  final List<Track> upcoming;
  final ValueChanged<Track> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.hairline)),
      ),
      child: SizedBox(
        width: NowPlayingPage.upNextWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UP NEXT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.inkMuted,
                  letterSpacing: 1.4,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: upcoming.isEmpty
                    ? Text(
                        'Nothing up next.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.inkMuted,
                        ),
                      )
                    : ListView.separated(
                        itemCount: upcoming.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: palette.hairlineSoft),
                        itemBuilder: (context, index) {
                          final track = upcoming[index];
                          return GestureDetector(
                            onTap: () => onSelect(track),
                            behavior: HitTestBehavior.opaque,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: palette.ink),
                                    ),
                                    if (track.artist != null)
                                      Text(
                                        track.artist!,
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
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
