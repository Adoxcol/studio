import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final playback = ref.watch(
      playbackControllerProvider.select(
        (s) => (queueIds: s.queueIds, trackId: s.trackId),
      ),
    );
    final tracks = ref.watch(libraryTracksProvider).value ?? const [];
    final byId = {for (final track in tracks) track.id: track};

    if (playback.queueIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: Text(
          'Queue is empty.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
      itemExtent: 45,
      cacheExtent: 400,
      addAutomaticKeepAlives: false,
      itemCount: playback.queueIds.length,
      itemBuilder: (context, index) {
        final id = playback.queueIds[index];
        final track = byId[id];
        final current = id == playback.trackId;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.hairlineSoft)),
          ),
          child: SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                track?.title ?? 'Unknown track',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: current ? palette.accent : palette.ink,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
