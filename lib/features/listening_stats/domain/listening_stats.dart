import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';

enum StatsPeriod {
  week('Last 7 days'),
  month('Last 30 days'),
  year('This year'),
  all('All time');

  const StatsPeriod(this.label);
  final String label;

  /// First instant included, in local time; null means everything.
  DateTime? startFrom(DateTime now) => switch (this) {
    StatsPeriod.week => DateTime(now.year, now.month, now.day - 6),
    StatsPeriod.month => DateTime(now.year, now.month, now.day - 29),
    StatsPeriod.year => DateTime(now.year),
    StatsPeriod.all => null,
  };
}

class RankedItem {
  const RankedItem({required this.label, required this.plays, this.detail});

  final String label;
  final String? detail;
  final int plays;

  @override
  String toString() => '$label ($plays)';
}

/// Totals and rankings for a set of plays.
class ListeningStats {
  const ListeningStats({
    required this.plays,
    required this.listening,
    required this.artists,
    required this.days,
    required this.topArtists,
    required this.topAlbums,
    required this.topTracks,
    required this.playsByMonth,
    required this.longestStreak,
    this.busiestDay,
    this.busiestDayPlays = 0,
  });

  static const empty = ListeningStats(
    plays: 0,
    listening: Duration.zero,
    artists: 0,
    days: 0,
    topArtists: [],
    topAlbums: [],
    topTracks: [],
    playsByMonth: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    longestStreak: 0,
  );

  final int plays;
  final Duration listening;

  /// Distinct credited artists heard.
  final int artists;

  /// Distinct local calendar days with at least one play.
  final int days;
  final List<RankedItem> topArtists;
  final List<RankedItem> topAlbums;
  final List<RankedItem> topTracks;

  /// Plays per calendar month, January first, across every year included.
  final List<int> playsByMonth;

  /// Most consecutive local days with a play.
  final int longestStreak;
  final DateTime? busiestDay;
  final int busiestDayPlays;

  static ListeningStats from(Iterable<PlayEvent> events, {int top = 10}) {
    var plays = 0;
    var listeningMs = 0;
    final artists = <String, (String, int)>{};
    final albums = <(String, String), (String, String, int)>{};
    final tracks = <String, (String, String?, int)>{};
    final perDay = <DateTime, int>{};
    final byMonth = List<int>.filled(12, 0);

    void bump<K>(Map<K, (String, int)> map, K key, String label) {
      final seen = map[key];
      map[key] = (seen?.$1 ?? label, (seen?.$2 ?? 0) + 1);
    }

    for (final event in events) {
      plays++;
      listeningMs += event.durationMs ?? 0;
      final local = event.playedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      perDay[day] = (perDay[day] ?? 0) + 1;
      byMonth[local.month - 1]++;

      final credits = LibraryQuery.creditedArtists(
        event.artist,
      ).where((a) => a != LibraryQuery.unknownArtist).toList();
      for (final credit in credits) {
        bump(artists, credit.toLowerCase(), credit);
      }
      final lead = credits.firstOrNull;
      final album = event.album?.trim() ?? '';
      if (lead != null && album.isNotEmpty) {
        final key = (lead.toLowerCase(), album.toLowerCase());
        final seen = albums[key];
        albums[key] = (
          seen?.$1 ?? album,
          seen?.$2 ?? lead,
          (seen?.$3 ?? 0) + 1,
        );
      }
      final trackKey =
          event.trackId?.toString() ??
          '${event.title.toLowerCase()}\u0000${(event.artist ?? '').toLowerCase()}';
      final seenTrack = tracks[trackKey];
      tracks[trackKey] = (
        seenTrack?.$1 ?? event.title,
        seenTrack?.$2 ?? lead,
        (seenTrack?.$3 ?? 0) + 1,
      );
    }

    List<RankedItem> rank(Iterable<RankedItem> items) {
      final list = items.toList()
        ..sort((a, b) {
          final byPlays = b.plays.compareTo(a.plays);
          return byPlays != 0
              ? byPlays
              : a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
      return list.take(top).toList();
    }

    DateTime? busiest;
    var busiestPlays = 0;
    for (final entry in perDay.entries) {
      if (entry.value > busiestPlays ||
          (entry.value == busiestPlays && entry.key.isBefore(busiest!))) {
        busiest = entry.key;
        busiestPlays = entry.value;
      }
    }

    return ListeningStats(
      plays: plays,
      listening: Duration(milliseconds: listeningMs),
      artists: artists.length,
      days: perDay.length,
      topArtists: rank([
        for (final (label, count) in artists.values)
          RankedItem(label: label, plays: count),
      ]),
      topAlbums: rank([
        for (final (album, artist, count) in albums.values)
          RankedItem(label: album, detail: artist, plays: count),
      ]),
      topTracks: rank([
        for (final (title, artist, count) in tracks.values)
          RankedItem(label: title, detail: artist, plays: count),
      ]),
      playsByMonth: byMonth,
      longestStreak: _longestStreak(perDay.keys),
      busiestDay: busiest,
      busiestDayPlays: busiestPlays,
    );
  }

  static int _longestStreak(Iterable<DateTime> days) {
    final sorted = days.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in sorted) {
      // Calendar arithmetic, so daylight-saving shifts do not break a run.
      final expected = previous == null
          ? null
          : DateTime(previous.year, previous.month, previous.day + 1);
      run = expected != null && day == expected ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }
}
