import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/subsonic/data/subsonic_artist_pictures.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

SubsonicArtist _artist(String name) =>
    SubsonicArtist(id: name, name: name, coverArtId: 'ar-$name');

Uint8List _bytes(int seed) => Uint8List.fromList([seed, seed + 1, seed + 2]);

void main() {
  late MemoryArtistPictureStore store;
  late ArtistPictureRepository repository;

  setUp(() {
    store = MemoryArtistPictureStore();
    repository = ArtistPictureRepository(
      store: store,
      prepare: (bytes) async => bytes,
    );
  });

  tearDown(() => repository.dispose());

  SubsonicArtistPictureSync syncWith(
    Map<String, Uint8List?> images, {
    List<String>? calls,
    Set<String> failing = const {},
  }) {
    return SubsonicArtistPictureSync(
      repository: repository,
      fetch: (artist) async {
        calls?.add(artist.name);
        if (failing.contains(artist.name)) throw Exception('boom');
        return images[artist.name];
      },
    );
  }

  test('saves each artist portrait with the Navidrome credit', () async {
    final sync = syncWith({'Adele': _bytes(1), 'Bjork': _bytes(2)});

    await sync.sync([_artist('Adele'), _artist('Bjork')]);

    final adele = await repository.get('Adele');
    final bjork = await repository.get('Bjork');
    expect(adele.remotePath, isNotNull);
    expect(bjork.remotePath, isNot(adele.remotePath));
    expect(adele.credit?.source, 'Navidrome');
  });

  test('the server placeholder is not kept for anyone', () async {
    final placeholder = _bytes(9);
    final sync = syncWith({
      'Adele': placeholder,
      'Bjork': _bytes(2),
      'Cher': placeholder,
    });

    await sync.sync([_artist('Adele'), _artist('Bjork'), _artist('Cher')]);

    expect((await repository.get('Adele')).remotePath, isNull);
    expect((await repository.get('Cher')).remotePath, isNull);
    expect((await repository.get('Bjork')).remotePath, isNotNull);
  });

  test('placeholders saved by older versions are removed', () async {
    final placeholder = _bytes(9);
    // An older loop saved the same server image for two artists, one without
    // a credit, plus a real online photo that must survive.
    await repository.saveRemote('Adele', placeholder);
    await repository.saveRemote(
      'Cher',
      placeholder,
      credit: navidromePictureCredit,
    );
    await repository.saveRemote(
      'Dido',
      _bytes(4),
      credit: const PictureCredit(
        author: 'Someone',
        license: 'CC BY',
        pageUrl: '',
        licenseUrl: '',
      ),
    );

    final calls = <String>[];
    await syncWith(
      {},
      calls: calls,
    ).sync([_artist('Adele'), _artist('Cher'), _artist('Dido')]);

    expect((await repository.get('Adele')).remotePath, isNull);
    expect((await repository.get('Cher')).remotePath, isNull);
    expect((await repository.get('Dido')).remotePath, isNotNull);
    // Known placeholders are not downloaded again this session.
    expect(calls, isEmpty);
  });

  test('custom and existing portraits are left alone', () async {
    await repository.setCustom('Adele', _bytes(7));
    await repository.hide('Bjork');
    final calls = <String>[];

    await syncWith({
      'Adele': _bytes(1),
      'Bjork': _bytes(2),
    }, calls: calls).sync([_artist('Adele'), _artist('Bjork')]);

    expect(calls, isEmpty);
    expect((await repository.get('Adele')).isCustom, isTrue);
    expect((await repository.get('Bjork')).hidden, isTrue);
  });

  test('one failing artist does not stop the others', () async {
    final sync = syncWith(
      {'Adele': _bytes(1), 'Cher': _bytes(3)},
      failing: {'Bjork'},
    );

    await sync.sync([_artist('Adele'), _artist('Bjork'), _artist('Cher')]);

    expect((await repository.get('Adele')).remotePath, isNotNull);
    expect((await repository.get('Cher')).remotePath, isNotNull);
  });

  test('overlapping calls share one run', () async {
    final gate = Completer<void>();
    var fetches = 0;
    final sync = SubsonicArtistPictureSync(
      repository: repository,
      fetch: (artist) async {
        fetches++;
        await gate.future;
        return _bytes(1);
      },
    );

    final first = sync.sync([_artist('Adele')]);
    final second = sync.sync([_artist('Adele')]);
    gate.complete();
    await Future.wait([first, second]);

    expect(fetches, 1);
  });

  test('reports progress over the artists that need a portrait', () async {
    await repository.setCustom('Adele', _bytes(7));
    final progress = <(int, int)>[];

    await syncWith({'Bjork': _bytes(2), 'Cher': _bytes(3)}).sync([
      _artist('Adele'),
      _artist('Bjork'),
      _artist('Cher'),
    ], onProgress: (done, total) => progress.add((done, total)));

    expect(progress.first, (0, 2));
    expect(progress.last, (2, 2));
  });

  group('SubsonicClient.artistPictureBytes', () {
    const config = SubsonicServerConfig(
      serverUrl: 'https://music.example.com',
      username: 'me',
      password: 'secret',
    );

    test('prefers getCoverArt and rejects JSON errors', () async {
      final requested = <Uri>[];
      final client = SubsonicClient(
        config: config,
        httpClient: MockClient((request) async {
          requested.add(request.url);
          if (request.url.path.endsWith('/getCoverArt')) {
            return http.Response(
              jsonEncode({
                'subsonic-response': {'status': 'failed'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response.bytes(
            _bytes(5),
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );
      addTearDown(client.dispose);

      final bytes = await client.artistPictureBytes(
        const SubsonicArtist(
          id: '1',
          name: 'Adele',
          coverArtId: 'ar-1',
          artistImageUrl: 'https://lastfm.example.net/adele.jpg',
        ),
      );

      expect(bytes, _bytes(5));
      expect(requested.first.path, '/rest/getCoverArt');
      // The external image host never receives this server's credentials.
      final external = requested.last;
      expect(external.host, 'lastfm.example.net');
      expect(external.queryParameters.containsKey('t'), isFalse);
      expect(external.queryParameters.containsKey('u'), isFalse);
    });

    test('signs artistImageUrl only on the same server', () async {
      final requested = <Uri>[];
      final client = SubsonicClient(
        config: config,
        httpClient: MockClient((request) async {
          requested.add(request.url);
          return http.Response.bytes(
            _bytes(5),
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      addTearDown(client.dispose);

      await client.artistPictureBytes(
        const SubsonicArtist(
          id: '1',
          name: 'Adele',
          artistImageUrl: '/share/img/abc',
        ),
      );

      expect(requested.single.host, 'music.example.com');
      expect(requested.single.path, '/share/img/abc');
      expect(requested.single.queryParameters['u'], 'me');
    });
  });
}
