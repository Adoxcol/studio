import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/queue/queue_track_row.dart';

/// Queue-backed panel reserved for the future full-screen playback view.
class UpNextPanel extends ConsumerWidget {
  const UpNextPanel({super.key});

  static const double width = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(
      playbackControllerProvider.select(
        (state) => (trackId: state.trackId, queueIds: state.queueIds),
      ),
    );
    // ⚡ Bolt: Use pre-computed O(1) map for ID lookups instead of rebuilding
    // a Map of potentially tens of thousands of tracks on every playback change.
    final byId = ref.watch(libraryTracksByIdProvider);
    final currentIndex = playback.trackId == null
        ? -1
        : playback.queueIds.indexOf(playback.trackId!);
    final upcoming = [
      if (currentIndex >= 0)
        for (
          var queueIndex = currentIndex + 1;
          queueIndex < playback.queueIds.length;
          queueIndex++
        )
          if (byId[playback.queueIds[queueIndex]] case final track?)
            (queueIndex: queueIndex, track: track),
    ];
    final palette = StudioPalette.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.hairline)),
      ),
      child: SizedBox(
        width: width,
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
                          final entry = upcoming[index];
                          return QueueTrackRow(
                            track: entry.track,
                            onTap: () => ref
                                .read(playbackControllerProvider.notifier)
                                .playQueueIndex(entry.queueIndex),
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
