import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/audio_db_artist_picture_source.dart';
import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/features/artist_artwork/data/musicbrainz_artist_picture_lookup.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

const _id = '12345678-1234-1234-1234-123456789abc';
const _otherId = '22345678-1234-1234-1234-123456789abc';
Map<String, Object> _artist(String name, [String id = _id]) => {
  'name': name,
  'id': id,
};

class _Fixture {
  List<Map<String, Object>> artists = [_artist('Aria')];
  int? count;
  String relation = 'https://www.wikidata.org/wiki/Q123';
  String imageUrl = 'https://upload.wikimedia.org/example.jpg';
  String? author = '<a href="https://example.org">Photo &amp; Author</a>';
  String? license = 'CC BY-SA 4.0';
  String? licenseUrl = 'https://creativecommons.org/licenses/by-sa/4.0/';
  String? descriptionUrl = 'https://commons.wikimedia.org/wiki/File:Photo.jpg';
  String? usageTerms;
  bool includeMetadata = true;
  List<Map<String, Object>> releases = [];
  final requests = <http.Request>[];
  final times = <DateTime>[];
  Future<http.Response> call(http.Request request) async {
    requests.add(request);
    times.add(DateTime.now());
    final uri = request.url;
    if (uri.host == 'musicbrainz.org' && uri.path == '/ws/2/artist/') {
      return _json({'count': count ?? artists.length, 'artists': artists});
    }
    if (uri.path == '/ws/2/release-group/') {
      return _json({'count': releases.length, 'release-groups': releases});
    }
    if (uri.host == 'musicbrainz.org') {
      return _json({
        'relations': [
          {
            'type': 'wikidata',
            'url': {'resource': relation},
          },
        ],
      });
    }
    if (uri.host == 'www.wikidata.org') {
      return _json({
        'entities': {
          'Q123': {
            'claims': {
              'P18': [
                {
                  'rank': 'normal',
                  'mainsnak': {
                    'datavalue': {'value': 'Photo.jpg'},
                  },
                },
              ],
            },
          },
        },
      });
    }
    if (uri.host == 'commons.wikimedia.org') {
      return _json({
        'query': {
          'pages': {
            '1': {
              'imageinfo': [
                {
                  'thumburl': imageUrl,
                  if (descriptionUrl != null) 'descriptionurl': descriptionUrl,
                  if (includeMetadata)
                    'extmetadata': {
                      if (author != null) 'Artist': {'value': author},
                      if (license != null)
                        'LicenseShortName': {'value': license},
                      if (licenseUrl != null)
                        'LicenseUrl': {'value': licenseUrl},
                      if (usageTerms != null)
                        'UsageTerms': {'value': usageTerms},
                    },
                },
              ],
            },
          },
        },
      });
    }
    return http.Response.bytes([1, 2, 3], 200);
  }
}

http.Response _json(Object value) => http.Response(jsonEncode(value), 200);

class _AbortingClient extends http.BaseClient {
  final started = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    started.complete();
    await (request as http.Abortable).abortTrigger;
    throw http.RequestAbortedException(request.url);
  }
}

class _ProgressingClient extends http.BaseClient {
  bool abortedBeforeComplete = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var complete = false;
    (request as http.Abortable).abortTrigger?.then((_) {
      if (!complete) abortedBeforeComplete = true;
    });
    Stream<List<int>> chunks() async* {
      for (final chunk in ['{"count":', '0,', '"artists":', '[]}']) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        yield utf8.encode(chunk);
      }
      complete = true;
    }

    return http.StreamedResponse(chunks(), 200);
  }
}

void main() {
  // Synthetic credentials, not a user's keys.
  const keys = FanartSettings(
    projectKey: 'project-test-secret',
    personalKey: 'personal-test-secret',
  );
  late _Fixture fixture;
  late MusicBrainzArtistPictureLookup lookup;
  late List<String> logs;
  setUp(() {
    fixture = _Fixture();
    logs = [];
    lookup = MusicBrainzArtistPictureLookup(
      client: MockClient(fixture.call),
      requestSpacing: Duration.zero,
      log: ArtistPictureLog(logs.add),
    );
  });
  tearDown(() => lookup.close());

  test(
    'TheAudioDB fills a fanart miss using the already verified identity',
    () async {
      lookup.close();
      final requests = <http.Request>[];
      lookup = MusicBrainzArtistPictureLookup(
        fanart: keys,
        audioDb: AudioDbArtistPictureSource(requestSpacing: Duration.zero),
        requestSpacing: Duration.zero,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'webservice.fanart.tv') {
            return http.Response('', 404);
          }
          if (request.url.host == 'www.theaudiodb.com') {
            return _json({
              'artists': [
                {
                  'idArtist': '123456',
                  'strMusicBrainzID': _id,
                  'strArtistThumb':
                      'https://r2.theaudiodb.com/images/media/artist/thumb/a.jpg',
                },
              ],
            });
          }
          return fixture.call(request);
        }),
      );
      final picture = await lookup.fetch(const ArtistImageRequest('Aria'));
      expect(picture!.credit.source, 'TheAudioDB');
      expect(requests.map((r) => r.url.host), [
        'musicbrainz.org',
        'webservice.fanart.tv',
        'www.theaudiodb.com',
        'r2.theaudiodb.com',
      ]);
      expect(requests[2].headers.containsKey('api-key'), isFalse);
      expect(requests[3].headers.containsKey('client-key'), isFalse);
    },
  );

  test(
    'AudioDB outage falls back without losing the error when every other source misses',
    () async {
      lookup.close();
      lookup = MusicBrainzArtistPictureLookup(
        enableAudioDb: true,
        requestSpacing: Duration.zero,
        client: MockClient((request) async {
          if (request.url.host == 'www.theaudiodb.com') {
            return http.Response('Busy', 429);
          }
          return fixture.call(request);
        }),
      );
      expect(
        (await lookup.fetch(const ArtistImageRequest('Aria')))!.credit.source,
        'Wikimedia Commons',
      );
      fixture.relation = 'https://invalid.example/Q123';
      await expectLater(
        lookup.fetch(const ArtistImageRequest('Aria')),
        throwsA(
          isA<ArtistServiceException>().having((e) => e.status, 'status', 429),
        ),
      );
    },
  );

  test(
    'fanart authenticates metadata only, selects portraits, skips MB relations',
    () async {
      lookup.close();
      final requests = <http.Request>[];
      lookup = MusicBrainzArtistPictureLookup(
        fanart: keys,
        requestSpacing: Duration.zero,
        log: ArtistPictureLog(logs.add),
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'webservice.fanart.tv') {
            return _json({
              'mbid_id': _id,
              'artistthumb': [
                {
                  'id': '1',
                  'likes': '2',
                  'url': 'https://assets.fanart.tv/low.jpg',
                },
                {
                  'id': '2',
                  'likes': '9',
                  'url': 'https://assets.fanart.tv/best.jpg',
                },
              ],
            });
          }
          return fixture.call(request);
        }),
      );
      final image = await lookup.fetch(const ArtistImageRequest('Aria'));
      expect(image!.credit.source, 'fanart.tv');
      expect(image.credit.license, isNot(contains('Creative Commons')));
      expect(requests.map((r) => r.url.host), [
        'musicbrainz.org',
        'webservice.fanart.tv',
        'assets.fanart.tv',
      ]);
      expect(requests.last.url.path, '/best.jpg');
      for (final request in requests) {
        final auth = request.url.host == 'webservice.fanart.tv';
        expect(request.headers['api-key'], auth ? keys.projectKey : null);
        expect(request.headers['client-key'], auth ? keys.personalKey : null);
        expect(request.url.toString(), isNot(contains('secret')));
      }
      expect(logs.join(), isNot(contains('secret')));
    },
  );

  test(
    'missing fanart falls back; rejected keys are not hammered per artist',
    () async {
      for (final status in [404, 401]) {
        lookup.close();
        var calls = 0;
        lookup = MusicBrainzArtistPictureLookup(
          fanart: keys,
          requestSpacing: Duration.zero,
          client: MockClient((request) async {
            if (request.url.host == 'webservice.fanart.tv') {
              calls++;
              return http.Response(
                'Never log this response body: secret',
                status,
              );
            }
            return fixture.call(request);
          }),
          log: ArtistPictureLog(logs.add),
        );
        expect(
          (await lookup.fetch(const ArtistImageRequest('Aria')))!.credit.source,
          'Wikimedia Commons',
        );
        await lookup.fetch(const ArtistImageRequest('Aria'));
        expect(calls, status == 401 ? 1 : 2);
        if (status == 401) {
          lookup.configureFanart(keys);
          await lookup.fetch(const ArtistImageRequest('Aria'));
          expect(calls, 2);
        }
      }
      expect(logs.join(), isNot(contains('secret')));
    },
  );

  test(
    'fanart rate limits carry server retry deadline and retain identity',
    () async {
      lookup.close();
      final identities = ArtistIdentityStore();
      var searches = 0;
      lookup = MusicBrainzArtistPictureLookup(
        identities: identities,
        fanart: keys,
        requestSpacing: Duration.zero,
        client: MockClient((request) async {
          if (request.url.host == 'webservice.fanart.tv') {
            return http.Response('Busy', 429, headers: {'retry-after': '120'});
          }
          searches++;
          return fixture.call(request);
        }),
      );
      for (var i = 0; i < 2; i++) {
        final start = DateTime.now();
        await expectLater(
          lookup.fetch(const ArtistImageRequest('Aria')),
          throwsA(
            isA<ArtistServiceException>().having(
              (e) => e.retryAfter!.difference(start).inSeconds,
              'retry seconds',
              greaterThanOrEqualTo(119),
            ),
          ),
        );
      }
      expect(searches, 1);
      expect(await identities.load(const ArtistImageRequest('Aria')), _id);
    },
  );

  test(
    'fanart rejects mismatched identity and never follows unsafe asset URLs',
    () async {
      lookup.close();
      var id = _otherId;
      lookup = MusicBrainzArtistPictureLookup(
        fanart: keys,
        requestSpacing: Duration.zero,
        client: MockClient((request) async {
          if (request.url.host == 'webservice.fanart.tv') {
            return _json({
              'mbid_id': id,
              'artistthumb': [
                {'url': 'https://evil.example/photo.jpg'},
                {'url': 'http://assets.fanart.tv/photo.jpg'},
                {'url': 'https://assets.fanart.tv/photo.jpg?secret=foo'},
              ],
            });
          }
          return fixture.call(request);
        }),
      );
      await expectLater(
        lookup.fetch(const ArtistImageRequest('Aria')),
        throwsFormatException,
      );
      id = _id;
      expect(
        (await lookup.fetch(const ArtistImageRequest('Aria')))!.credit.source,
        'Wikimedia Commons',
      );
      expect(
        fixture.requests.every(
          (r) =>
              !r.url.host.contains('evil') && r.url.host != 'assets.fanart.tv',
        ),
        isTrue,
      );
    },
  );

  test(
    'identity-to-photo chain preserves author and license; identifies client',
    () async {
      final picture = await lookup.fetch(const ArtistImageRequest('ARIA'));
      expect(picture!.bytes, [1, 2, 3]);
      expect(picture.credit.author, 'Photo & Author');
      expect(picture.credit.license, 'CC BY-SA 4.0');
      expect(fixture.requests, hasLength(5));
      expect(logs, contains(contains('["ARIA"] MusicBrainz match: $_id')));
      expect(logs, contains(contains('Following Wikidata entry Q123')));
      expect(logs, contains(contains('Downloading Commons photo "Photo.jpg"')));
      expect(
        logs,
        contains(contains('HTTP 200 from upload.wikimedia.org: 3 bytes')),
      );
      expect(logs.any((line) => line.contains('?query=')), isFalse);
      expect(fixture.requests.first.headers['User-Agent'], contains('Studio/'));
      expect(
        fixture.requests.every((request) => !request.followRedirects),
        isTrue,
      );
    },
  );

  test(
    'fuzzy name, ambiguous name and truncated results are not guessed',
    () async {
      fixture.artists = [_artist('Ariadne')];
      expect(await lookup.fetch(const ArtistImageRequest('Aria')), isNull);
      fixture.artists = [_artist('Aria'), _artist('Aria', _otherId)];
      expect(await lookup.fetch(const ArtistImageRequest('Aria')), isNull);
      fixture.artists = [_artist('Aria')];
      fixture.count = 101;
      expect(await lookup.fetch(const ArtistImageRequest('Aria')), isNull);
      expect(fixture.requests, hasLength(3));
      expect(logs, contains(contains('No exact artist match')));
      expect(logs, contains(contains('artist identity is ambiguous')));
      expect(logs, contains(contains('results are truncated')));
    },
  );

  test(
    'ambiguous artist needs an exact album and matching credit id',
    () async {
      fixture.artists = [_artist('Aria'), _artist('Aria', _otherId)];
      fixture.releases = [
        {
          'title': 'Blue',
          'artist-credit': [
            {
              'artist': {'id': _otherId},
            },
          ],
        },
      ];
      expect(
        await lookup.fetch(const ArtistImageRequest('Aria', albums: ['Blue'])),
        isNotNull,
      );
      expect(fixture.requests[2].url.path, '/ws/2/artist/$_otherId');
    },
  );

  test('two artists with the same album stay ambiguous', () async {
    fixture.artists = [_artist('Aria'), _artist('Aria', _otherId)];
    fixture.releases = [
      for (final id in [_id, _otherId])
        {
          'title': 'Blue',
          'artist-credit': [
            {
              'artist': {'id': id},
            },
          ],
        },
    ];
    expect(
      await lookup.fetch(const ArtistImageRequest('Aria', albums: ['Blue'])),
      isNull,
    );
    expect(fixture.requests, hasLength(2));
  });

  test('unknown artists never go online and query syntax is escaped', () async {
    expect(
      await lookup.fetch(const ArtistImageRequest('Unknown artist')),
      isNull,
    );
    expect(fixture.requests, isEmpty);
    await lookup.fetch(const ArtistImageRequest('AC/DC + "Live"'));
    expect(
      fixture.requests.single.url.queryParameters['query'],
      r'artist:"AC\/DC \+ \"Live\""',
    );
  });

  test('untrusted relation and image hosts are still skipped', () async {
    fixture.relation = 'https://www.wikidata.org.evil.example/Q123';
    expect(await lookup.fetch(const ArtistImageRequest('Aria')), isNull);
    expect(fixture.requests, hasLength(2));
    fixture.relation = 'https://www.wikidata.org/wiki/Q123';
    fixture.imageUrl = 'http://127.0.0.1/private';
    expect(await lookup.fetch(const ArtistImageRequest('Aria')), isNull);
    expect(fixture.requests.where((r) => r.url.host == '127.0.0.1'), isEmpty);
  });

  test('Commons photo without an author keeps its available license', () async {
    fixture.author = null;
    final picture = await lookup.fetch(const ArtistImageRequest('Aria'));
    expect(picture!.bytes, [1, 2, 3]);
    expect(picture.credit.author, 'Author not supplied');
    expect(picture.credit.license, 'CC BY-SA 4.0');
    expect(picture.credit.licenseUrl, fixture.licenseUrl);
    expect(
      logs,
      contains(contains('metadata incomplete (author); downloading')),
    );
  });

  test(
    'Commons photo without a license is downloaded with unknown licensing',
    () async {
      fixture.license = null;
      fixture.licenseUrl = null;
      final picture = await lookup.fetch(const ArtistImageRequest('Aria'));
      expect(picture!.bytes, [1, 2, 3]);
      expect(picture.credit.author, 'Photo & Author');
      expect(picture.credit.license, 'License information not supplied');
      expect(picture.credit.licenseUrl, isEmpty);
      expect(picture.credit.pageUrl, fixture.descriptionUrl);
    },
  );

  test(
    'Commons uses supplied usage terms when the short license is absent',
    () async {
      fixture.license = '  ';
      fixture.usageTerms = '<b>Attribution required</b>';
      final picture = await lookup.fetch(const ArtistImageRequest('Aria'));
      expect(picture!.credit.license, 'Attribution required');
      expect(picture.credit.licenseUrl, fixture.licenseUrl);
    },
  );

  test(
    'Commons missing its description URL retains credits and links the file',
    () async {
      fixture.descriptionUrl = null;
      final picture = await lookup.fetch(const ArtistImageRequest('Aria'));
      expect(picture!.bytes, [1, 2, 3]);
      expect(
        picture.credit.pageUrl,
        'https://commons.wikimedia.org/wiki/File:Photo.jpg',
      );
      expect(picture.credit.author, 'Photo & Author');
      expect(picture.credit.license, 'CC BY-SA 4.0');
    },
  );

  test('Commons photo with no credit metadata still downloads', () async {
    fixture.includeMetadata = false;
    fixture.descriptionUrl = null;
    final picture = await lookup.fetch(const ArtistImageRequest('Aria'));
    expect(picture!.bytes, [1, 2, 3]);
    expect(picture.credit.source, 'Wikimedia Commons');
    expect(picture.credit.author, 'Author not supplied');
    expect(picture.credit.license, 'License information not supplied');
    expect(picture.credit.licenseUrl, isEmpty);
    expect(
      picture.credit.pageUrl,
      'https://commons.wikimedia.org/wiki/File:Photo.jpg',
    );
    expect(
      logs,
      contains(contains('metadata incomplete (author, license, source page)')),
    );
  });

  test('server failures are not cached as definitive misses', () async {
    lookup.close();
    lookup = MusicBrainzArtistPictureLookup(
      client: MockClient((_) async => http.Response('Busy', 503)),
      requestSpacing: Duration.zero,
    );
    await expectLater(
      lookup.fetch(const ArtistImageRequest('Aria')),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('oversized responses are rejected before JSON decoding', () async {
    lookup.close();
    lookup = MusicBrainzArtistPictureLookup(
      client: MockClient(
        (_) async => http.Response('x' * (2 * 1024 * 1024 + 1), 200),
      ),
      requestSpacing: Duration.zero,
    );
    await expectLater(
      lookup.fetch(const ArtistImageRequest('Aria')),
      throwsFormatException,
    );
  });

  test('request timeout actually aborts the network request', () async {
    lookup.close();
    final client = _AbortingClient();
    lookup = MusicBrainzArtistPictureLookup(
      client: client,
      requestTimeout: const Duration(milliseconds: 10),
    );
    await expectLater(
      lookup.fetch(const ArtistImageRequest('Aria')),
      throwsA(isA<http.RequestAbortedException>()),
    );
  });

  test(
    'progressing transfers may exceed idle timeout without being aborted',
    () async {
      lookup.close();
      final client = _ProgressingClient();
      lookup = MusicBrainzArtistPictureLookup(
        client: client,
        requestTimeout: const Duration(milliseconds: 160),
      );
      expect(await lookup.fetch(const ArtistImageRequest('Aria')), isNull);
      expect(client.abortedBeforeComplete, isFalse);
    },
  );

  test('hard transfer deadline still bounds an unresponsive request', () async {
    lookup.close();
    final client = _AbortingClient();
    lookup = MusicBrainzArtistPictureLookup(
      client: client,
      requestTimeout: const Duration(seconds: 5),
      transferTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      lookup.fetch(const ArtistImageRequest('Aria')),
      throwsA(isA<http.RequestAbortedException>()),
    );
  });

  test('cancel aborts the active request', () async {
    lookup.close();
    final client = _AbortingClient();
    lookup = MusicBrainzArtistPictureLookup(client: client);
    final future = lookup.fetch(const ArtistImageRequest('Aria'));
    final expectation = expectLater(
      future,
      throwsA(isA<http.RequestAbortedException>()),
    );
    await client.started.future;
    lookup.cancel();
    await expectation;
  });

  test('rate spacing applies across requests and across artists', () async {
    lookup.close();
    lookup = MusicBrainzArtistPictureLookup(
      client: MockClient(fixture.call),
      requestSpacing: const Duration(milliseconds: 25),
    );
    await lookup.fetch(const ArtistImageRequest('Aria'));
    await lookup.fetch(const ArtistImageRequest('No match'));
    for (var i = 1; i < fixture.times.length; i++) {
      expect(
        fixture.times[i].difference(fixture.times[i - 1]).inMilliseconds,
        greaterThanOrEqualTo(24),
      );
    }
    expect(
      MusicBrainzArtistPictureLookup(
        client: MockClient(fixture.call),
      ).requestSpacing,
      greaterThanOrEqualTo(const Duration(seconds: 1)),
    );
  });
}
