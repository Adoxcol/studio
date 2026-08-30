import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/track_details/domain/track_details.dart';

import '../../helpers/tracks.dart';

void main() {
  test('album membership uses lead artist and album, then track order', () {
    final song = testTrack(
      id: 1,
      artist: 'Aria feat. Hal',
      album: 'Blue',
      trackNumber: 2,
    );
    final first = testTrack(
      id: 2,
      artist: 'Aria',
      album: 'Blue',
      trackNumber: 1,
    );
    final unrelated = testTrack(id: 3, artist: 'Hal', album: 'Blue');
    final otherAlbum = testTrack(id: 4, artist: 'Aria', album: 'Red');
    final details = TrackDetails(
      track: song,
      library: [song, unrelated, first, otherAlbum],
    );

    expect(details.credits, ['Aria', 'Hal']);
    expect(details.albumTracks.map((track) => track.id), [2, 1]);
    expect(details.albumDurationMs, 476000);
    expect(details.artistTracks.map((track) => track.id), [1, 2, 4]);
  });

  test(
    'artist catalog includes guest credits on other lead artists albums',
    () {
      final song = testTrack(id: 1, artist: 'Hal');
      final guest = testTrack(id: 2, artist: 'Aria feat. Hal');
      final details = TrackDetails(track: song, library: [song, guest]);
      expect(details.artistTracks.map((track) => track.id), [1, 2]);
      expect(details.artistAlbums.map((section) => section.artist), [
        'Aria',
        'Hal',
      ]);
    },
  );

  test('missing tags do not merge unrelated unknown albums or artists', () {
    final song = testTrack(id: 1, artist: null, album: null);
    final other = testTrack(id: 2, artist: null, album: null);
    final details = TrackDetails(track: song, library: [song, other]);
    expect(details.albumTracks.map((track) => track.id), [1]);
    expect(details.artistTracks.map((track) => track.id), [1]);
  });

  test('unknown duration never appears as a complete album total', () {
    final song = testTrack(id: 1);
    final unknown = testTrack(id: 2, durationMs: null);
    expect(
      TrackDetails(track: song, library: [song, unknown]).albumDurationMs,
      isNull,
    );
  });
}
