import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';

/// One index per immutable database snapshot. Values reference the original
/// tracks; images and binary metadata never enter this cache.
class LibraryIndex {
  LibraryIndex(this.tracks);

  final List<Track> tracks;
  final _credits = <String?, List<String>>{};
  late final Map<int, Track> byId = Map.unmodifiable({
    for (final track in tracks) track.id: track,
  });
  late final _search = [
    for (final track in tracks)
      [
        track.title,
        track.artist ?? '',
        track.album ?? '',
        track.genre ?? '',
      ].map((text) => text.toLowerCase()).toList(growable: false),
  ];
  late final Map<String, List<Track>> _byArtist = _artistIndex();
  late final Map<(String, String), List<Track>> _byAlbum = _albumIndex();

  List<String> creditsOf(Track track) => _credits.putIfAbsent(
    track.artist,
    () => List.unmodifiable(LibraryQuery.creditedArtists(track.artist)),
  );

  String artistOf(Track track) => creditsOf(track).first;

  List<Track> forArtist(String artist) =>
      _byArtist[artist.toLowerCase()] ?? const [];

  List<Track> forAlbum(String artist, String album) =>
      _byAlbum[(artist.toLowerCase(), album.toLowerCase())] ?? const [];

  Map<String, List<Track>> _artistIndex() {
    final result = <String, List<Track>>{};
    for (final track in tracks) {
      for (final credit in creditsOf(track)) {
        result.putIfAbsent(credit.toLowerCase(), () => []).add(track);
      }
    }
    return result.map((key, value) => MapEntry(key, List.unmodifiable(value)));
  }

  Map<(String, String), List<Track>> _albumIndex() {
    final result = <(String, String), List<Track>>{};
    for (final track in tracks) {
      final key = (
        artistOf(track).toLowerCase(),
        LibraryQuery.albumName(track).toLowerCase(),
      );
      result.putIfAbsent(key, () => []).add(track);
    }
    return result.map((key, value) => MapEntry(key, List.unmodifiable(value)));
  }

  List<Track> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return tracks;
    return [
      for (var i = 0; i < tracks.length; i++)
        if (_search[i].any((field) => field.contains(needle))) tracks[i],
    ];
  }
}

/// Owned by the library page, replaced when its query or snapshot changes.
/// Lazy members avoid sorting tracks or grouping inactive catalogue tabs.
class LibraryView {
  LibraryView({
    required this.index,
    this.query = '',
    this.artist,
    this.album,
    this.genre,
    this.folderId,
    this.filters = const LibraryTrackFilters(),
    required this.sort,
    required this.order,
  });

  final LibraryIndex index;
  final String query;
  final String? artist;
  final String? album;
  final String? genre;
  final int? folderId;
  final LibraryTrackFilters filters;
  final LibrarySort sort;
  final LibraryOrder order;

  late final searched = index.search(query);
  late final filtered = [
    for (final track in searched)
      if ((folderId == null || track.folderId == folderId) &&
          filters.matches(track) &&
          (artist == null ||
              index
                  .creditsOf(track)
                  .any(
                    (credit) => LibraryQuery.compareText(credit, artist!) == 0,
                  )) &&
          (album == null || LibraryQuery.albumName(track) == album) &&
          (genre == null || LibraryQuery.genreName(track) == genre))
        track,
  ];
  late final sorted = LibraryQuery.sorted(
    tracks: filtered,
    sort: sort,
    order: order,
    artistOf: index.artistOf,
  );
  late final artists = LibraryQuery.groupArtists(
    filtered,
    order: order,
    creditsOf: index.creditsOf,
  );
  late final albums = LibraryQuery.albumSections(
    filtered,
    order: order,
    artistOf: index.artistOf,
  );
  late final genres = LibraryQuery.groupGenres(filtered, order: order);
}
