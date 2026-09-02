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

  test('detects lossless formats and estimates bitrate from size', () {
    final flac = testTrack(
      locator: '/music/MASTER.FLAC?cache=1',
      durationMs: 200000,
      fileSizeBytes: 25000000,
    );
    expect(LibraryQuery.isLossless(flac), isTrue);
    expect(LibraryQuery.isLossless(testTrack(locator: '/music/song.mp3')), isFalse);
    expect(LibraryQuery.estimatedBitrateKbps(flac), 1000);
    expect(
      LibraryQuery.estimatedBitrateKbps(
        testTrack(durationMs: null, fileSizeBytes: 100),
      ),
      isNull,
    );
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

  test('sorts by track number then album and title', () {
    final numbered = [
      testTrack(id: 1, title: 'Zebra', trackNumber: 2, album: 'Afterglow'),
      testTrack(id: 2, title: 'Alpha', trackNumber: 1, album: 'Afterglow'),
      testTrack(
        id: 3,
        title: 'No number',
        trackNumber: null,
        album: 'Afterglow',
      ),
      testTrack(
        id: 4,
        title: 'Opener',
        trackNumber: 1,
        album: 'Nightlight',
        artist: 'Halvard Iyer',
      ),
    ];
    expect(
      LibraryQuery.sorted(
        tracks: numbered,
        sort: LibrarySort.track,
        order: LibraryOrder.ascending,
      ).map((t) => t.title),
      ['Alpha', 'Opener', 'Zebra', 'No number'],
    );
  });

  test('album sort keeps disc order inside each album', () {
    final numbered = [
      testTrack(id: 1, title: 'zebra', trackNumber: 2, album: 'Afterglow'),
      testTrack(id: 2, title: 'alpha', trackNumber: 1, album: 'Afterglow'),
      testTrack(
        id: 3,
        title: 'opener',
        trackNumber: 1,
        album: 'Nightlight',
        artist: 'Halvard Iyer',
      ),
    ];
    expect(
      LibraryQuery.sorted(
        tracks: numbered,
        sort: LibrarySort.album,
        order: LibraryOrder.ascending,
      ).map((t) => t.title),
      ['alpha', 'zebra', 'opener'],
    );
    expect(
      LibraryQuery.sorted(
        tracks: numbered,
        sort: LibrarySort.album,
        order: LibraryOrder.descending,
      ).map((t) => t.title),
      ['opener', 'alpha', 'zebra'],
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

  test('groups collabs under the first credited artist', () {
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage & Metro Boomin'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('A. R. Rahman & Gulzar'),
      'A. R. Rahman',
    );
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage feat. Drake'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage (feat. Drake)'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage ft. Metro Boomin'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage x Metro Boomin'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage, Lil Durk'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('21 Savage, Offset, Metro Boomin'),
      '21 Savage',
    );
    expect(
      LibraryQuery.firstCreditedArtist('Tyler, The Creator'),
      'Tyler, The Creator',
    );
    expect(LibraryQuery.firstCreditedArtist('A\$AP Rocky'), 'A\$AP Rocky');
    expect(LibraryQuery.creditedArtists('Drake feat. 21 Savage'), [
      'Drake',
      '21 Savage',
    ]);
    expect(LibraryQuery.creditedArtists('Drake, 21 Savage'), [
      'Drake',
      '21 Savage',
    ]);
    expect(LibraryQuery.creditedArtists('Tyler, The Creator feat. 21 Savage'), [
      'Tyler, The Creator',
      '21 Savage',
    ]);

    final collabs = [
      testTrack(
        id: 10,
        title: 'Rich Flex',
        artist: '21 Savage & Metro Boomin',
        album: 'Her Loss',
      ),
      testTrack(
        id: 11,
        title: 'a lot',
        artist: '21 Savage',
        album: 'i am > i was',
      ),
      testTrack(
        id: 13,
        title: 'Bank Account',
        artist: '21 Savage, Offset',
        album: 'Without Warning',
      ),
      testTrack(
        id: 12,
        title: 'Chaiyya Chaiyya',
        artist: 'A. R. Rahman & Gulzar',
        album: 'Dil Se',
      ),
      testTrack(
        id: 14,
        title: 'Jimmy Cooks',
        artist: 'Drake feat. 21 Savage',
        album: 'Honestly, Nevermind',
      ),
    ];
    final artists = LibraryQuery.groupArtists(collabs);
    expect(artists.map((g) => g.name), [
      '21 Savage',
      'A. R. Rahman',
      'Drake',
      'Gulzar',
      'Metro Boomin',
      'Offset',
    ]);
    expect(artists.first.name, '21 Savage');
    expect(artists.first.albumCount, 4);
    expect(artists.first.trackCount, 4);
    expect(
      LibraryQuery.filter(
        tracks: collabs,
        artist: '21 Savage',
      ).map((t) => t.id),
      [10, 11, 13, 14],
    );
    expect(
      LibraryQuery.filter(tracks: collabs, artist: 'Drake').map((t) => t.id),
      [14],
    );

    final albums = LibraryQuery.albumSections(collabs);
    expect(albums.map((s) => s.artist), ['21 Savage', 'A. R. Rahman', 'Drake']);
    expect(albums.first.albums.map((a) => a.name), [
      'Her Loss',
      'i am > i was',
      'Without Warning',
    ]);
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
    expect(albums.first.albums.single.year, isNull);

    final dated = LibraryQuery.albumSections([
      testTrack(
        id: 1,
        album: 'Old Light',
        year: 2018,
        artworkPath: '/covers/old.jpg',
      ),
      testTrack(
        id: 2,
        album: 'New Light',
        year: 2024,
        artworkPath: '/covers/new.jpg',
      ),
    ]);
    expect(dated.single.albums.map((a) => a.name), ['New Light', 'Old Light']);
    expect(dated.single.albums.first.year, 2024);
    expect(dated.single.albums.first.artworkPath, '/covers/new.jpg');

    final genres = LibraryQuery.groupGenres(tracks);
    expect(genres.map((g) => g.name), [
      'Electronic',
      'Neo-classical',
      LibraryQuery.unknownGenre,
    ]);
  });

  test('albumCaption joins album and year', () {
    expect(
      LibraryQuery.albumCaption(testTrack(album: 'Afterglow', year: 2024)),
      'Afterglow · 2024',
    );
    expect(
      LibraryQuery.albumCaption(testTrack(album: 'Afterglow')),
      'Afterglow',
    );
    expect(
      LibraryQuery.albumCaption(testTrack(album: null, year: 2024)),
      '2024',
    );
  });

  test('sort and order cycle', () {
    expect(LibraryQuery.nextSort(LibrarySort.album), LibrarySort.track);
    expect(LibraryQuery.nextSort(LibrarySort.track), LibrarySort.time);
    expect(LibraryQuery.nextSort(LibrarySort.time), LibrarySort.title);
    expect(
      LibraryQuery.toggleOrder(LibraryOrder.ascending),
      LibraryOrder.descending,
    );
  });
}
