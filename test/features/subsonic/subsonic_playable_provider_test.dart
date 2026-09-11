import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/data/subsonic_playable_provider.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/providers/playable_resolver.dart';

void main() {
  group('SubsonicPlayableProvider', () {
    const config = SubsonicServerConfig(
      serverUrl: 'https://music.example.com',
      username: 'user123',
      password: 'secretpassword',
    );

    test('resolves playable for subsonic source track', () async {
      final client = SubsonicClient(config: config);
      final provider = SubsonicPlayableProvider(client: client);

      const locator = TrackLocator(
        source: TrackLocator.subsonic,
        locator: 'song-42',
      );

      final playable = await provider.resolve(locator);
      expect(playable.scheme, 'https');
      expect(playable.path, '/rest/stream');
      expect(playable.queryParameters['id'], 'song-42');
      client.dispose();
    });

    test('throws ArgumentError for non-subsonic sources', () async {
      final client = SubsonicClient(config: config);
      final provider = SubsonicPlayableProvider(client: client);

      const locator = TrackLocator(
        source: TrackLocator.local,
        locator: 'C:\\music\\track.mp3',
      );

      expect(() => provider.resolve(locator), throwsArgumentError);
      client.dispose();
    });
  });
}
