import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/listening_stats/domain/listening_stats.dart';
import 'package:studio/features/scrobbling/domain/scrobble_tracker.dart';
import 'package:studio/library/database.dart';
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

/// A period's stats, with the same-length stretch just before it for
/// comparison (null for all time).
class PeriodReport {
  const PeriodReport(this.stats, {this.previous});

  final ListeningStats stats;
  final ListeningStats? previous;
}

/// Genre of a play, from the library track it came from.
String? Function(PlayEvent) _genreLookup(Ref ref) {
  final tracks = ref.watch(libraryTracksByIdProvider);
  return (event) => event.trackId == null ? null : tracks[event.trackId]?.genre;
}

final listeningStatsProvider = FutureProvider.autoDispose
    .family<PeriodReport, StatsPeriod>((ref, period) async {
      ref.watch(playCountProvider);
      final genreOf = _genreLookup(ref);
      final now = ref.watch(statsClockProvider)();
      final db = ref.watch(studioDatabaseProvider);
      final start = period.startFrom(now);
      final events = await db.playEventsBetween(from: start?.toUtc());
      if (start == null) {
        return PeriodReport(ListeningStats.from(events, genreOf: genreOf));
      }
      final earlier = await db.playEventsBetween(to: start.toUtc());
      final span = now.difference(start);
      final previousStart = start.subtract(span);
      final previous = earlier.where(
        (e) => !e.playedAt.toLocal().isBefore(previousStart),
      );
      return PeriodReport(
        ListeningStats.from(
          events,
          genreOf: genreOf,
          knownArtists: ListeningStats.artistsIn(earlier),
        ),
        previous: ListeningStats.from(previous, top: 0),
      );
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
