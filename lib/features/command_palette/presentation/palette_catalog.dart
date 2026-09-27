import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';

typedef PaletteArtist = ({String name, int tracks});
typedef PaletteAlbum = ({String artist, String album, int tracks});

/// Display-cased artists and albums, rebuilt only when the library changes.
class PaletteCatalog {
  const PaletteCatalog({required this.artists, required this.albums});

  final List<PaletteArtist> artists;
  final List<PaletteAlbum> albums;
}

final paletteCatalogProvider = Provider<PaletteCatalog>((ref) {
  final index = ref.watch(libraryIndexProvider);
  final artists = <String, (String, int)>{};
  final albums = <(String, String), (String, String, int)>{};
  for (final track in index.tracks) {
    for (final credit in index.creditsOf(track)) {
      if (credit == LibraryQuery.unknownArtist) continue;
      final key = credit.toLowerCase();
      final seen = artists[key];
      artists[key] = (seen?.$1 ?? credit, (seen?.$2 ?? 0) + 1);
    }
    final artist = index.artistOf(track);
    final album = LibraryQuery.albumName(track);
    if (artist == LibraryQuery.unknownArtist ||
        album == LibraryQuery.unknownAlbum) {
      continue;
    }
    final key = (artist.toLowerCase(), album.toLowerCase());
    final seen = albums[key];
    albums[key] = (seen?.$1 ?? artist, seen?.$2 ?? album, (seen?.$3 ?? 0) + 1);
  }
  return PaletteCatalog(
    artists: [
      for (final (name, tracks) in artists.values) (name: name, tracks: tracks),
    ],
    albums: [
      for (final (artist, album, tracks) in albums.values)
        (artist: artist, album: album, tracks: tracks),
    ],
  );
});
