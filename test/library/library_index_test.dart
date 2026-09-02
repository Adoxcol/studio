import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/library_index.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/features/track_details/domain/track_details.dart';

import '../helpers/tracks.dart';

void main() {
  final tracks = [
    testTrack(id: 1, title: 'One', artist: 'Aria feat. Hal', album: 'Blue'),
    testTrack(id: 2, title: 'Two', artist: 'HAL', album: 'Blue'),
    testTrack(id: 3, title: 'Three', artist: 'Aria feat. Hal', album: 'Red'),
    testTrack(id: 4, title: 'Four', artist: null, album: null),
  ];

  test('index preserves query semantics and reuses parsed credits', () {
    final index = LibraryIndex(tracks);
    expect(index.creditsOf(tracks[0]), same(index.creditsOf(tracks[2])));
    expect(index.forArtist('hal').map((t) => t.id), [1, 2, 3]);
    expect(index.forAlbum('aria', 'BLUE').map((t) => t.id), [1]);
    for (final query in ['', '  blue ', 'HAL', 'missing', 'One']) {
      expect(
        index.search(query),
        LibraryQuery.filter(tracks: tracks, query: query),
      );
    }
  });

  test('derived views are memoized and invalidate with a new snapshot', () {
    final index = LibraryIndex(tracks);
    final view = LibraryView(
      index: index,
      sort: LibrarySort.artist,
      order: LibraryOrder.ascending,
    );
    expect(view.sorted, same(view.sorted));
    expect(view.artists, same(view.artists));
    expect(view.albums, same(view.albums));
    expect(view.genres, same(view.genres));
    expect(
      view.sorted,
      LibraryQuery.sorted(
        tracks: tracks,
        sort: LibrarySort.artist,
        order: LibraryOrder.ascending,
      ),
    );
    final refreshed = LibraryIndex([tracks.first.copyWith(title: 'Changed')]);
    expect(refreshed.byId[1]!.title, 'Changed');
    expect(refreshed.forArtist('hal').length, 1);
    expect(index.byId[1]!.title, 'One');
  });

  test('details use indexed membership and memoize album groups', () {
    final index = LibraryIndex(tracks);
    final details = TrackDetails(
      track: tracks[0],
      library: tracks,
      index: index,
    );
    expect(details.artistTracks.map((t) => t.id), [1, 3]);
    expect(details.albumTracks.map((t) => t.id), [1]);
    expect(details.artistAlbums, same(details.artistAlbums));
    expect(details.genres, same(details.genres));
  });

  test('quality filters combine and also constrain catalogue groups', () {
    final candidates = [
      testTrack(
        id: 10,
        title: 'Studio Master',
        artist: 'Aria',
        genre: 'Jazz',
        year: 2025,
        locator: '/music/master.flac',
        durationMs: 100000,
        fileSizeBytes: 12500000,
        sampleRateHz: 96000,
        folderId: 2,
      ),
      testTrack(
        id: 11,
        title: 'Compressed',
        artist: 'Hal',
        genre: 'Jazz',
        year: 2025,
        locator: '/music/song.mp3',
        durationMs: 100000,
        fileSizeBytes: 4000000,
        sampleRateHz: 44100,
        folderId: 2,
      ),
    ];
    final view = LibraryView(
      index: LibraryIndex(candidates),
      sort: LibrarySort.title,
      order: LibraryOrder.ascending,
      filters: const LibraryTrackFilters(
        losslessOnly: true,
        minimumSampleRateHz: 88200,
        minimumBitrateKbps: 900,
        genre: 'Jazz',
        year: 2025,
        folderId: 2,
      ),
    );

    expect(view.filtered.map((track) => track.id), [10]);
    expect(view.artists.map((group) => group.name), ['Aria']);
    expect(view.albums.single.albums.single.trackCount, 1);
  });
}
