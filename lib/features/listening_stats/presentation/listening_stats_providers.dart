import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/listening_stats/domain/listening_stats.dart';
import 'package:studio/features/scrobbling/domain/scrobble_tracker.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

/// Clock for stats periods; overridden in tests.
final statsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Records a play each time a track passes the scrobble threshold, so
/// history counts listens the same way Last.fm and ListenBrainz do.
final playHistoryRecorderProvider = Provider<void>((ref) {
  final db = ref.watch(studioDatabaseProvider);
  final tracker = ScrobbleTracker();
  ref.listen(playbackControllerProvider, (_, playback) {
    for (final event in tracker.observe(playback)) {
      if (event is! ScrobbleReadyEvent) continue;
      final track = event.track;
      unawaited(
        db
            .recordPlay(
              trackId: playback.trackId,
              title: track.title,
              artist: track.artist,
              album: track.album,
              durationMs: track.duration.inMilliseconds,
              playedAt: track.startedAt,
            )
            .catchError((Object error) {
              debugPrint('Could not record play: $error');
            }),
      );
    }
  });
});

/// Changes whenever a play is recorded or history is cleared.
final playCountProvider = StreamProvider<int>((ref) {
  return ref.watch(studioDatabaseProvider).watchPlayCount();
});

final listeningStatsProvider = FutureProvider.autoDispose
    .family<ListeningStats, StatsPeriod>((ref, period) async {
      ref.watch(playCountProvider);
      final now = ref.watch(statsClockProvider)();
      final events = await ref
          .watch(studioDatabaseProvider)
          .playEventsBetween(from: period.startFrom(now)?.toUtc());
      return ListeningStats.from(events);
    });

/// A calendar year's plays, for the year-in-review summary.
final yearInReviewProvider = FutureProvider.autoDispose
    .family<ListeningStats, int>((ref, year) async {
      ref.watch(playCountProvider);
      final events = await ref
          .watch(studioDatabaseProvider)
          .playEventsBetween(
            from: DateTime(year).toUtc(),
            to: DateTime(year + 1).toUtc(),
          );
      return ListeningStats.from(events, top: 5);
    });
