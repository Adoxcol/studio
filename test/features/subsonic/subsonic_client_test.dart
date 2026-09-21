import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

void main() {
  group('SubsonicClient', () {
    const config = SubsonicServerConfig(
      serverUrl: 'https://music.example.com',
      username: 'user123',
      password: 'secretpassword',
    );

    test('buildStreamUri includes auth parameters and song id', () {
      final client = SubsonicClient(config: config);
      final uri = client.buildStreamUri('song-456');

      expect(uri.scheme, 'https');
      expect(uri.host, 'music.example.com');
      expect(uri.path, '/rest/stream');
      expect(uri.queryParameters['id'], 'song-456');
      expect(uri.queryParameters['u'], 'user123');
      expect(uri.queryParameters['v'], '1.16.1');
      expect(uri.queryParameters['c'], 'studio');
      expect(uri.queryParameters['f'], 'json');
      expect(uri.queryParameters.containsKey('s'), isTrue);
      expect(uri.queryParameters.containsKey('t'), isTrue);
      client.dispose();
    });

    test('buildCoverArtUri includes auth parameters and id', () {
      final client = SubsonicClient(config: config);
      final uri = client.buildCoverArtUri('cover-789', size: 300);

      expect(uri, isNotNull);
      expect(uri!.path, '/rest/getCoverArt');
      expect(uri.queryParameters['id'], 'cover-789');
      expect(uri.queryParameters['size'], '300');
      expect(uri.queryParameters['u'], 'user123');
      client.dispose();
    });

    test('handles trailing slash in serverUrl properly', () {
      const configWithSlash = SubsonicServerConfig(
        serverUrl: 'https://music.example.com/',
        username: 'user123',
        password: 'secretpassword',
      );
      final client = SubsonicClient(config: configWithSlash);
      final uri = client.buildStreamUri('song-1');
      expect(uri.path, '/rest/stream');
      client.dispose();
    });

    test(
      'buildEndpointUri includes extraParams such as type, size and offset',
      () {
        final client = SubsonicClient(config: config);
        final uri = client.buildEndpointUri('getAlbumList2', {
          'type': 'alphabeticalByName',
          'size': '100',
          'offset': '200',
        });
        expect(uri.path, '/rest/getAlbumList2');
        expect(uri.queryParameters['type'], 'alphabeticalByName');
        expect(uri.queryParameters['size'], '100');
        expect(uri.queryParameters['offset'], '200');
        client.dispose();
      },
    );

    test('SubsonicScanState tracks progress percentage properly', () {
      const state = SubsonicScanState(
        isScanning: true,
        currentAlbum: 50,
        totalAlbums: 100,
        totalTracks: 540,
        currentAlbumName: 'Abbey Road',
      );
      expect(state.progress, 0.5);
      expect(state.isScanning, isTrue);

      final updated = state.copyWith(
        currentAlbum: 100,
        isCompleted: true,
        isScanning: false,
      );
      expect(updated.progress, 1.0);
      expect(updated.isCompleted, isTrue);
      expect(updated.isScanning, isFalse);
    });

    test('SubsonicPlaylist deserializes from JSON correctly', () {
      final json = {
        'id': 'pl-1',
        'name': 'Daft Punk Favorites',
        'comment': 'Best of Daft Punk',
        'owner': 'admin',
        'public': true,
        'songCount': 12,
        'duration': 2880,
        'created': '2026-01-01T12:00:00Z',
        'changed': '2026-01-02T15:30:00Z',
        'coverArt': 'pl-cover-1',
      };

      final playlist = SubsonicPlaylist.fromJson(json);
      expect(playlist.id, 'pl-1');
      expect(playlist.name, 'Daft Punk Favorites');
      expect(playlist.comment, 'Best of Daft Punk');
      expect(playlist.owner, 'admin');
      expect(playlist.isPublic, isTrue);
      expect(playlist.songCount, 12);
      expect(playlist.durationSeconds, 2880);
      expect(playlist.created, DateTime.parse('2026-01-01T12:00:00Z'));
      expect(playlist.changed, DateTime.parse('2026-01-02T15:30:00Z'));
      expect(playlist.coverArtId, 'pl-cover-1');
    });
  });
}
