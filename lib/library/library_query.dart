import 'package:studio/library/database.dart';

enum LibraryTab { all, artists, albums, genres, playlists, recentlyAdded }

enum LibrarySort { title, artist, album, time }

enum LibraryOrder { ascending, descending }

class LibraryGroup {
  const LibraryGroup({
    required this.name,
    required this.trackCount,
    this.albumCount,
    this.subtitle,
  });

  final String name;
  final int trackCount;
  final int? albumCount;
  final String? subtitle;
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

  static String artistName(Track track) => _label(track.artist, unknownArtist);

  static String albumName(Track track) => _label(track.album, unknownAlbum);

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
            (artist == null || artistName(track) == artist) &&
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
  }) {
    final copy = [...tracks];
    copy.sort((a, b) {
      final cmp = byIndexedAt
          ? a.indexedAt.compareTo(b.indexedAt)
          : switch (sort) {
              LibrarySort.title => compareText(a.title, b.title),
              LibrarySort.artist => compareText(artistName(a), artistName(b)),
              LibrarySort.album => compareText(albumName(a), albumName(b)),
              LibrarySort.time => _compareDuration(a.durationMs, b.durationMs),
            };
      final directed = order == LibraryOrder.ascending ? cmp : -cmp;
      if (directed != 0) return directed;
      return compareText(a.title, b.title);
    });
    return copy;
  }

  static List<LibraryGroup> groupArtists(
    List<Track> tracks, {
    LibraryOrder order = LibraryOrder.ascending,
  }) {
    final albums = <String, Set<String>>{};
    final counts = <String, int>{};
    for (final track in tracks) {
      final artist = artistName(track);
      counts[artist] = (counts[artist] ?? 0) + 1;
      albums.putIfAbsent(artist, () => <String>{}).add(albumName(track));
    }
    return [
      for (final name in _sortedKeys(counts.keys, order))
        LibraryGroup(
          name: name,
          trackCount: counts[name]!,
          albumCount: albums[name]!.length,
        ),
    ];
  }

  static List<AlbumSection> albumSections(
    List<Track> tracks, {
    LibraryOrder order = LibraryOrder.ascending,
  }) {
    final byArtist = <String, Map<String, int>>{};
    for (final track in tracks) {
      final artist = artistName(track);
      final album = albumName(track);
      final albums = byArtist.putIfAbsent(artist, () => <String, int>{});
      albums[album] = (albums[album] ?? 0) + 1;
    }
    return [
      for (final artist in _sortedKeys(byArtist.keys, order))
        AlbumSection(
          artist: artist,
          albums: [
            for (final album in _sortedKeys(byArtist[artist]!.keys, order))
              LibraryGroup(name: album, trackCount: byArtist[artist]![album]!),
          ],
        ),
    ];
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

  static int _compareDuration(int? a, int? b) {
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

extension LibraryTabX on LibraryTab {
  String get label => switch (this) {
    LibraryTab.all => 'All',
    LibraryTab.artists => 'Artists',
    LibraryTab.albums => 'Albums',
    LibraryTab.genres => 'Genres',
    LibraryTab.playlists => 'Playlists',
    LibraryTab.recentlyAdded => 'Recently Added',
  };
}

extension LibrarySortX on LibrarySort {
  String get label => switch (this) {
    LibrarySort.title => 'Title',
    LibrarySort.artist => 'Artist',
    LibrarySort.album => 'Album',
    LibrarySort.time => 'Time',
  };
}

extension LibraryOrderX on LibraryOrder {
  String get label => switch (this) {
    LibraryOrder.ascending => 'A–Z',
    LibraryOrder.descending => 'Z–A',
  };
}
