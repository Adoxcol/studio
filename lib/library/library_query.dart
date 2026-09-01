import 'package:studio/library/database.dart';

enum LibraryTab { all, artists, albums, genres, playlists, folders }

enum LibrarySort { title, artist, album, track, time }

enum LibraryOrder { ascending, descending }

class LibraryGroup {
  const LibraryGroup({
    required this.name,
    required this.trackCount,
    this.albumCount,
    this.subtitle,
    this.artworkPath,
    this.year,
  });

  final String name;
  final int trackCount;
  final int? albumCount;
  final String? subtitle;
  final String? artworkPath;
  final int? year;
}

class AlbumSection {
  const AlbumSection({required this.artist, required this.albums});

  final String artist;
  final List<LibraryGroup> albums;
}

abstract final class LibraryQuery {
  static const unknownArtist = 'Unknown artist';
  static const unknownAlbum = 'Unknown album';
  static const unknownGenre = 'Unknown genre';

  static String artistName(Track track) =>
      firstCreditedArtist(_label(track.artist, unknownArtist));

  /// Lead artist. Albums stay under this name; featured names still appear
  /// in that person's catalog via [creditedArtists].
  static String firstCreditedArtist(String artist) =>
      creditedArtists(artist).first;

  /// Every credited name, primary first. "Drake feat. 21 Savage" is Drake
  /// and 21 Savage — not a third combined artist.
  static List<String> creditedArtists(String? artist) {
    final labeled = _label(artist, unknownArtist);
    if (labeled == unknownArtist) return const [unknownArtist];
    final names = _uniqueCredits(_splitCredits(labeled));
    return names.isEmpty ? const [unknownArtist] : names;
  }

  static bool creditsInclude(Track track, String artist) {
    return creditedArtists(
      track.artist,
    ).any((name) => compareText(name, artist) == 0);
  }

  static List<String> _splitCredits(String artist) {
    final extras = <String>[];
    final lead = artist.replaceAllMapped(_featParenthetical, (match) {
      extras.addAll(_splitCollabList(match.group(1)!));
      return '';
    }).trim();
    final names = <String>[
      for (final chunk in lead.split(_featureSplit)) ..._splitCollabList(chunk),
      ...extras,
    ];
    return names;
  }

  static List<String> _splitCollabList(String chunk) {
    final names = <String>[];
    for (final collab in chunk.split(_collabSplit)) {
      final piece = collab.trim();
      if (piece.isEmpty) continue;
      if (_theCommaName.hasMatch(piece)) {
        names.add(piece);
      } else {
        names.addAll(
          piece
              .split(_commaSplit)
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty),
        );
      }
    }
    return names;
  }

  static List<String> _uniqueCredits(List<String> names) {
    final seen = <String>{};
    final unique = <String>[];
    for (final name in names) {
      final key = name.toLowerCase();
      if (seen.add(key)) unique.add(name);
    }
    return unique;
  }

  static final _featParenthetical = RegExp(
    r'\s*[\(\[]\s*(?:feat(?:uring)?\.?|ft\.?)\s*([^\)\]]+)[\)\]]?',
    caseSensitive: false,
  );

  static final _featureSplit = RegExp(
    r'\s+(?:feat(?:uring)?\.?|ft\.?)\s+',
    caseSensitive: false,
  );

  static final _collabSplit = RegExp(
    r'\s+(?:&|and|x|×|/|;)\s+',
    caseSensitive: false,
  );

  static final _commaSplit = RegExp(r'\s*,\s*');

  /// "Tyler, The Creator" — one comma, then The.
  static final _theCommaName = RegExp(
    r'^[^,]+,\s+The\s+\S+$',
    caseSensitive: false,
  );

  static String albumName(Track track) => _label(track.album, unknownAlbum);

  static String albumCaption(Track track) {
    final album = albumName(track);
    final year = track.year;
    final hasYear = year != null && year > 0;
    if (!hasYear) {
      return album == unknownAlbum ? '' : album;
    }
    if (album == unknownAlbum) return '$year';
    return '$album · $year';
  }

  static String genreName(Track track) => _label(track.genre, unknownGenre);

  static bool matchesQuery(Track track, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return _contains(track.title, needle) ||
        _contains(track.artist, needle) ||
        _contains(track.album, needle) ||
        _contains(track.genre, needle);
  }

  static List<Track> filter({
    required List<Track> tracks,
    String query = '',
    String? artist,
    String? album,
    String? genre,
  }) {
    return [
      for (final track in tracks)
        if (matchesQuery(track, query) &&
            (artist == null || creditsInclude(track, artist)) &&
            (album == null || albumName(track) == album) &&
            (genre == null || genreName(track) == genre))
          track,
    ];
  }

  static List<Track> sorted({
    required List<Track> tracks,
    required LibrarySort sort,
    required LibraryOrder order,
    bool byIndexedAt = false,
    String Function(Track)? artistOf,
  }) {
    final copy = [...tracks];
    // Normalize once per row, not on every O(n log n) comparison.
    final textKeys = <int, String>{
      if (!byIndexedAt &&
          (sort == LibrarySort.title ||
              sort == LibrarySort.artist ||
              sort == LibrarySort.album))
        for (final track in tracks)
          track.id: (switch (sort) {
            LibrarySort.artist => (artistOf ?? artistName)(track),
            LibrarySort.album => albumName(track),
            _ => track.title,
          }).toLowerCase(),
    };
    copy.sort((a, b) {
      final cmp = byIndexedAt
          ? a.indexedAt.compareTo(b.indexedAt)
          : switch (sort) {
              LibrarySort.title ||
              LibrarySort.artist ||
              LibrarySort.album => textKeys[a.id]!.compareTo(textKeys[b.id]!),
              LibrarySort.track => _compareNullableInt(
                a.trackNumber,
                b.trackNumber,
              ),
              LibrarySort.time => _compareNullableInt(
                a.durationMs,
                b.durationMs,
              ),
            };
      final directed = order == LibraryOrder.ascending ? cmp : -cmp;
      if (directed != 0) return directed;
      if (sort == LibrarySort.track) {
        final albums = compareText(albumName(a), albumName(b));
        if (albums != 0) return albums;
      }
      if (sort == LibrarySort.album) {
        final tracks = _compareNullableInt(a.trackNumber, b.trackNumber);
        if (tracks != 0) return tracks;
      }
      return compareText(a.title, b.title);
    });
    return copy;
  }

  static List<LibraryGroup> groupArtists(
    List<Track> tracks, {
    LibraryOrder order = LibraryOrder.ascending,
    List<String> Function(Track)? creditsOf,
  }) {
    final albums = <String, Set<String>>{};
    final counts = <String, int>{};
    final labels = <String, String>{};
    for (final track in tracks) {
      for (final artist
          in creditsOf?.call(track) ?? creditedArtists(track.artist)) {
        final key = artist.toLowerCase();
        labels.putIfAbsent(key, () => artist);
        counts[key] = (counts[key] ?? 0) + 1;
        albums.putIfAbsent(key, () => <String>{}).add(albumName(track));
      }
    }
    return [
      for (final name in _sortedKeys(labels.values, order))
        LibraryGroup(
          name: name,
          trackCount: counts[name.toLowerCase()]!,
          albumCount: albums[name.toLowerCase()]!.length,
        ),
    ];
  }

  static List<AlbumSection> albumSections(
    List<Track> tracks, {
    LibraryOrder order = LibraryOrder.ascending,
    String Function(Track)? artistOf,
  }) {
    final byArtist = <String, Map<String, _AlbumAgg>>{};
    for (final track in tracks) {
      final artist = (artistOf ?? artistName)(track);
      final album = albumName(track);
      final albums = byArtist.putIfAbsent(artist, () => <String, _AlbumAgg>{});
      final agg = albums.putIfAbsent(album, _AlbumAgg.new);
      agg.trackCount++;
      agg.artworkPath ??= track.artworkPath;
      final year = track.year;
      if (agg.year == null && year != null && year > 0) {
        agg.year = year;
      }
    }
    return [
      for (final artist in _sortedKeys(byArtist.keys, order))
        AlbumSection(
          artist: artist,
          albums: _sortedAlbumGroups(byArtist[artist]!, order),
        ),
    ];
  }

  static List<LibraryGroup> _sortedAlbumGroups(
    Map<String, _AlbumAgg> albums,
    LibraryOrder order,
  ) {
    final names = albums.keys.toList()
      ..sort((a, b) {
        final yearCmp = _compareAlbumYear(albums[a]!.year, albums[b]!.year);
        if (yearCmp != 0) return yearCmp;
        final namesCmp = compareText(a, b);
        return order == LibraryOrder.ascending ? namesCmp : -namesCmp;
      });
    return [
      for (final name in names)
        LibraryGroup(
          name: name,
          trackCount: albums[name]!.trackCount,
          artworkPath: albums[name]!.artworkPath,
          year: albums[name]!.year,
        ),
    ];
  }

  /// Newer albums first; missing year last.
  static int _compareAlbumYear(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  static List<LibraryGroup> groupGenres(
    List<Track> tracks, {
    LibraryOrder order = LibraryOrder.ascending,
  }) {
    final counts = <String, int>{};
    for (final track in tracks) {
      final genre = genreName(track);
      counts[genre] = (counts[genre] ?? 0) + 1;
    }
    return [
      for (final name in _sortedKeys(counts.keys, order))
        LibraryGroup(name: name, trackCount: counts[name]!),
    ];
  }

  static LibrarySort nextSort(LibrarySort sort) {
    return LibrarySort.values[(sort.index + 1) % LibrarySort.values.length];
  }

  static LibraryOrder toggleOrder(LibraryOrder order) {
    return order == LibraryOrder.ascending
        ? LibraryOrder.descending
        : LibraryOrder.ascending;
  }

  static int compareText(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static String _label(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return fallback;
    return trimmed;
  }

  static bool _contains(String? value, String needle) {
    return (value ?? '').toLowerCase().contains(needle);
  }

  static int _compareNullableInt(int? a, int? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  static List<String> _sortedKeys(Iterable<String> keys, LibraryOrder order) {
    final names = keys.toList()..sort(compareText);
    if (order == LibraryOrder.descending) {
      return names.reversed.toList();
    }
    return names;
  }
}

class _AlbumAgg {
  int trackCount = 0;
  String? artworkPath;
  int? year;
}

extension LibraryTabX on LibraryTab {
  String get label => switch (this) {
    LibraryTab.all => 'All',
    LibraryTab.artists => 'Artists',
    LibraryTab.albums => 'Albums',
    LibraryTab.genres => 'Genres',
    LibraryTab.playlists => 'Playlists',
    LibraryTab.folders => 'Folders',
  };
}

extension LibrarySortX on LibrarySort {
  String get label => switch (this) {
    LibrarySort.title => 'Title',
    LibrarySort.artist => 'Artist',
    LibrarySort.album => 'Album',
    LibrarySort.track => 'Track',
    LibrarySort.time => 'Time',
  };
}

extension LibraryOrderX on LibraryOrder {
  String get label => switch (this) {
    LibraryOrder.ascending => 'A–Z',
    LibraryOrder.descending => 'Z–A',
  };
}
