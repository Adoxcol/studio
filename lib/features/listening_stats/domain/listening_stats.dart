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
  const RankedItem({
    required this.label,
    required this.plays,
    this.detail,
    this.trackId,
  });

  final String label;
  final String? detail;
  final int plays;

  /// A library track behind this entry, for its artwork. Null when every
  /// play came from a track that has since been removed.
  final int? trackId;

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
    this.albums = 0,
    this.tracks = 0,
    this.playsByHour = const [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ],
    this.playsByWeekday = const [0, 0, 0, 0, 0, 0, 0],
    this.topGenres = const [],
    this.newArtists = const [],
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

  /// Distinct albums and tracks heard.
  final int albums;
  final int tracks;

  /// Plays by local hour, midnight first.
  final List<int> playsByHour;

  /// Plays by local weekday, Monday first.
  final List<int> playsByWeekday;
  final List<RankedItem> topGenres;

  /// Artists first heard in these plays, most played first. Empty unless
  /// earlier history was given.
  final List<RankedItem> newArtists;

  /// Mean listening per day with at least one play.
  Duration get perDay => days == 0
      ? Duration.zero
      : Duration(milliseconds: listening.inMilliseconds ~/ days);

  /// [genreOf] names a play's genre (from its library track), and
  /// [knownArtists] holds the lowercased artists heard before these plays,
  /// for [newArtists].
  static ListeningStats from(
    Iterable<PlayEvent> events, {
    int top = 10,
    String? Function(PlayEvent event)? genreOf,
    Set<String>? knownArtists,
  }) {
    var plays = 0;
    var listeningMs = 0;
    final artists = <String, (String, int)>{};
    final albums = <(String, String), (String, String, int, int?)>{};
    final tracks = <String, (String, String?, int, int?)>{};
    final genres = <String, (String, int)>{};
    final perDay = <DateTime, int>{};
    final byMonth = List<int>.filled(12, 0);
    final byHour = List<int>.filled(24, 0);
    final byWeekday = List<int>.filled(7, 0);

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
      byHour[local.hour]++;
      byWeekday[local.weekday - 1]++;
      final genre = genreOf?.call(event)?.trim();
      if (genre != null && genre.isNotEmpty) {
        bump(genres, genre.toLowerCase(), genre);
      }

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
          seen?.$4 ?? event.trackId,
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
        seenTrack?.$4 ?? event.trackId,
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
        for (final (album, artist, count, trackId) in albums.values)
          RankedItem(
            label: album,
            detail: artist,
            plays: count,
            trackId: trackId,
          ),
      ]),
      topTracks: rank([
        for (final (title, artist, count, trackId) in tracks.values)
          RankedItem(
            label: title,
            detail: artist,
            plays: count,
            trackId: trackId,
          ),
      ]),
      playsByMonth: byMonth,
      longestStreak: _longestStreak(perDay.keys),
      busiestDay: busiest,
      busiestDayPlays: busiestPlays,
      albums: albums.length,
      tracks: tracks.length,
      playsByHour: byHour,
      playsByWeekday: byWeekday,
      topGenres: rank([
        for (final (label, count) in genres.values)
          RankedItem(label: label, plays: count),
      ]),
      newArtists: knownArtists == null
          ? const []
          : rank([
              for (final MapEntry(:key, value: (label, count))
                  in artists.entries)
                if (!knownArtists.contains(key))
                  RankedItem(label: label, plays: count),
            ]),
    );
  }

  /// Lowercased credited artists across [events], for `knownArtists`.
  static Set<String> artistsIn(Iterable<PlayEvent> events) => {
    for (final event in events)
      for (final credit in LibraryQuery.creditedArtists(event.artist))
        if (credit != LibraryQuery.unknownArtist) credit.toLowerCase(),
  };

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
