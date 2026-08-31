import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';

/// Local-library metadata for one song; never combines same-named albums
/// belonging to different lead artists.
class TrackDetails {
  factory TrackDetails({required Track track, required List<Track> library}) {
    final credits = LibraryQuery.creditedArtists(track.artist);
    final artist = credits.first;
    final album = LibraryQuery.albumName(track);
    final unknownArtist = artist == LibraryQuery.unknownArtist;
    final unknownAlbum = album == LibraryQuery.unknownAlbum;
    final artistTracks = <Track>[];
    final albumTracks = <Track>[];
    // Parse each credit once and share the results between both collections.
    for (final candidate in library) {
      final candidateCredits = LibraryQuery.creditedArtists(candidate.artist);
      final sameTrack = candidate.id == track.id;
      if (unknownArtist
          ? sameTrack
          : candidateCredits.any(
              (credit) => LibraryQuery.compareText(credit, artist) == 0,
            )) {
        artistTracks.add(candidate);
      }
      // Missing tags do not establish that unrelated files share an album.
      if (unknownArtist || unknownAlbum
          ? sameTrack
          : LibraryQuery.compareText(candidateCredits.first, artist) == 0 &&
                LibraryQuery.compareText(
                      LibraryQuery.albumName(candidate),
                      album,
                    ) ==
                    0) {
        albumTracks.add(candidate);
      }
    }
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

  const TrackDetails._({
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

  List<AlbumSection> get artistAlbums =>
      LibraryQuery.albumSections(artistTracks);

  List<String> get genres =>
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
