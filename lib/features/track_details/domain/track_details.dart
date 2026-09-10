import 'package:studio/library/database.dart';
import 'package:studio/library/library_index.dart';
import 'package:studio/library/library_query.dart';

/// Local-library metadata for one song; never combines same-named albums
/// belonging to different lead artists.
class TrackDetails {
  factory TrackDetails({
    required Track track,
    required List<Track> library,
    LibraryIndex? index,
  }) {
    final catalog = index ?? LibraryIndex(library);
    final credits = catalog.creditsOf(track);
    final artist = credits.first;
    final album = LibraryQuery.albumName(track);
    final unknownArtist = artist == LibraryQuery.unknownArtist;
    final unknownAlbum = album == LibraryQuery.unknownAlbum;
    final sameTrack = catalog.byId[track.id];
    final fallback = <Track>[?sameTrack];
    final artistTracks = unknownArtist ? fallback : catalog.forArtist(artist);
    // Missing tags cannot establish that unrelated files share an album.
    final albumTracks = unknownArtist || unknownAlbum
        ? fallback
        : catalog.forAlbum(artist, album);
    return TrackDetails._(
      track: track,
      artist: artist,
      credits: List.unmodifiable(credits),
      album: album,
      artistTracks: List.unmodifiable(artistTracks),
      albumTracks: List.unmodifiable(
        LibraryQuery.sorted(
          tracks: albumTracks,
          sort: LibrarySort.track,
          order: LibraryOrder.ascending,
        ),
      ),
    );
  }

  TrackDetails._({
    required this.track,
    required this.artist,
    required this.credits,
    required this.album,
    required this.artistTracks,
    required this.albumTracks,
  });

  final Track track;
  final String artist;
  final List<String> credits;
  final String album;
  final List<Track> artistTracks;
  final List<Track> albumTracks;

  late final List<AlbumSection> artistAlbums = LibraryQuery.albumSections(
    artistTracks,
  );

  late final List<String> genres =
      artistTracks
          .map(LibraryQuery.genreName)
          .where((genre) => genre != LibraryQuery.unknownGenre)
          .toSet()
          .toList()
        ..sort(LibraryQuery.compareText);

  /// A partial total would incorrectly imply that every track length is known.
  int? get albumDurationMs {
    if (albumTracks.isEmpty ||
        albumTracks.any(
          (track) => track.durationMs == null || track.durationMs! < 0,
        )) {
      return null;
    }
    return albumTracks.fold<int>(
      0,
      (total, track) => total + track.durationMs!,
    );
  }
}
