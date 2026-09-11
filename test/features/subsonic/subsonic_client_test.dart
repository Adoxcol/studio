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
  });
}
