import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/library_query.dart';

import '../helpers/tracks.dart';

void main() {
  final tracks = [
    testTrack(
      id: 1,
      title: 'Nocturne in Blue',
      artist: 'Aria Solvang',
      album: 'Afterglow',
      durationMs: 238000,
      genre: 'Neo-classical',
      indexedAt: DateTime.utc(2026, 1, 1),
    ),
    testTrack(
      id: 2,
      title: 'Glass Harbor',
      artist: 'Halvard Iyer',
      album: 'Nightlight',
      durationMs: 192000,
      genre: 'Electronic',
      indexedAt: DateTime.utc(2026, 1, 3),
    ),
    testTrack(
      id: 3,
      title: 'Second Light',
      artist: 'Aria Solvang',
      album: 'Afterglow',
      durationMs: 201000,
      genre: 'Neo-classical',
      indexedAt: DateTime.utc(2026, 1, 2),
    ),
    testTrack(
      id: 4,
      title: 'Untitled',
      artist: null,
      album: null,
      durationMs: null,
      genre: null,
      indexedAt: DateTime.utc(2026, 1, 4),
    ),
  ];

  test('search matches title, artist, album, and genre', () {
    expect(
      LibraryQuery.filter(tracks: tracks, query: 'harbor').single.title,
      'Glass Harbor',
    );
    expect(
      LibraryQuery.filter(tracks: tracks, query: 'aria').map((t) => t.id),
      [1, 3],
    );
    expect(
      LibraryQuery.filter(tracks: tracks, query: 'nightlight').single.id,
      2,
    );
    expect(
      LibraryQuery.filter(tracks: tracks, query: 'electronic').single.id,
      2,
    );
  });

  test('artist filter uses the unknown-artist label for missing tags', () {
    final unknown = LibraryQuery.filter(
      tracks: tracks,
      artist: LibraryQuery.unknownArtist,
    );
    expect(unknown.single.title, 'Untitled');
  });

  test('sorts by title, artist, album, and duration', () {
    expect(
      LibraryQuery.sorted(
        tracks: tracks,
        sort: LibrarySort.title,
        order: LibraryOrder.ascending,
      ).map((t) => t.title),
      ['Glass Harbor', 'Nocturne in Blue', 'Second Light', 'Untitled'],
    );
    expect(
      LibraryQuery.sorted(
        tracks: tracks,
        sort: LibrarySort.time,
        order: LibraryOrder.ascending,
      ).map((t) => t.title),
      ['Glass Harbor', 'Second Light', 'Nocturne in Blue', 'Untitled'],
    );
  });

  test('recently added sorts by indexedAt descending', () {
    expect(
      LibraryQuery.sorted(
        tracks: tracks,
        sort: LibrarySort.title,
        order: LibraryOrder.descending,
        byIndexedAt: true,
      ).map((t) => t.id),
      [4, 2, 3, 1],
    );
  });

  test('groups artists, albums, and genres', () {
    final artists = LibraryQuery.groupArtists(tracks);
    expect(artists.map((g) => g.name), [
      'Aria Solvang',
      'Halvard Iyer',
      LibraryQuery.unknownArtist,
    ]);
    expect(artists.first.albumCount, 1);
    expect(artists.first.trackCount, 2);

    final albums = LibraryQuery.albumSections(tracks);
    expect(albums.first.artist, 'Aria Solvang');
    expect(albums.first.albums.single.name, 'Afterglow');
    expect(albums.first.albums.single.trackCount, 2);

    final genres = LibraryQuery.groupGenres(tracks);
    expect(genres.map((g) => g.name), [
      'Electronic',
      'Neo-classical',
      LibraryQuery.unknownGenre,
    ]);
  });

  test('sort and order cycle', () {
    expect(LibraryQuery.nextSort(LibrarySort.time), LibrarySort.title);
    expect(
      LibraryQuery.toggleOrder(LibraryOrder.ascending),
      LibraryOrder.descending,
    );
  });
}
