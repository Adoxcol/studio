import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/features/scrobbling/data/lastfm_client.dart';
import 'package:studio/features/scrobbling/data/listenbrainz_client.dart';
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/domain/scrobble_track.dart';

final _track = ScrobbleTrack(
  artist: 'Björk',
  title: 'Jóga',
  album: 'Homogenic',
  duration: const Duration(seconds: 305),
  startedAt: DateTime.utc(2026, 9, 27, 12),
);

Matcher throwsFailure(ScrobbleFailure failure) => throwsA(
  isA<ScrobbleException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  group('Last.fm', () {
    test('signs sorted params without format, plus the secret', () {
      final expected = md5
          .convert(utf8.encode('api_keyKmethodauth.getTokentokenTsecret'))
          .toString();
      expect(
        LastFmClient.sign({
          'token': 'T',
          'method': 'auth.getToken',
          'api_key': 'K',
          'format': 'json',
        }, 'secret'),
        expected,
      );
    });

    test('scrobble posts indexed, signed fields', () async {
      late Map<String, String> body;
      final client = LastFmClient(
        apiKey: 'key',
        secret: 'secret',
        httpClient: MockClient((request) async {
          body = request.bodyFields;
          return http.Response('{"scrobbles":{}}', 200);
        }),
      );
      await client.scrobble('session', [_track]);
      expect(body['method'], 'track.scrobble');
      expect(body['sk'], 'session');
      expect(body['artist[0]'], 'Björk');
      expect(body['track[0]'], 'Jóga');
      expect(body['album[0]'], 'Homogenic');
      expect(body['duration[0]'], '305');
      expect(body['timestamp[0]'], '${_track.startedAtSeconds}');
      expect(body['format'], 'json');
      final unsigned = Map.of(body)..remove('api_sig');
      expect(body['api_sig'], LastFmClient.sign(unsigned, 'secret'));
    });

    test('desktop auth returns the approval page and the session', () async {
      final client = LastFmClient(
        apiKey: 'key',
        secret: 'secret',
        httpClient: MockClient((request) async {
          return switch (request.bodyFields['method']) {
            'auth.getToken' => http.Response('{"token":"tok"}', 200),
            _ => http.Response(
              '{"session":{"name":"rj","key":"sk1","subscriber":0}}',
              200,
            ),
          };
        }),
      );
      final token = await client.getToken();
      expect(client.authorizeUrl(token).queryParameters, {
        'api_key': 'key',
        'token': 'tok',
      });
      final session = await client.getSession(token);
      expect(session.key, 'sk1');
      expect(session.user, 'rj');
    });

    test('maps Last.fm errors to queue behaviour', () async {
      LastFmClient respond(int status, String body) => LastFmClient(
        apiKey: 'k',
        secret: 's',
        httpClient: MockClient((_) async => http.Response(body, status)),
      );
      await expectLater(
        respond(
          403,
          '{"error":9,"message":"Invalid session key"}',
        ).scrobble('sk', [_track]),
        throwsFailure(ScrobbleFailure.auth),
      );
      await expectLater(
        respond(
          200,
          '{"error":11,"message":"Service offline"}',
        ).scrobble('sk', [_track]),
        throwsFailure(ScrobbleFailure.retry),
      );
      await expectLater(
        respond(503, 'unavailable').scrobble('sk', [_track]),
        throwsFailure(ScrobbleFailure.retry),
      );
      await expectLater(
        respond(
          400,
          '{"error":6,"message":"Invalid parameters"}',
        ).scrobble('sk', [_track]),
        throwsFailure(ScrobbleFailure.rejected),
      );
    });
  });

  group('ListenBrainz', () {
    test('submits listens with the token header', () async {
      late http.Request sent;
      final client = ListenBrainzClient(
        token: 'tok',
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response('{"status":"ok"}', 200);
        }),
      );
      await client.submit([_track]);
      expect(sent.url.path, '/1/submit-listens');
      expect(sent.headers['Authorization'], 'Token tok');
      final json = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(json['listen_type'], 'single');
      final listen = (json['payload'] as List).single as Map<String, dynamic>;
      expect(listen['listened_at'], _track.startedAtSeconds);
      expect(listen['track_metadata']['artist_name'], 'Björk');
      expect(listen['track_metadata']['release_name'], 'Homogenic');
      expect(
        listen['track_metadata']['additional_info']['duration_ms'],
        305000,
      );

      await client.submit([_track, _track]);
      expect(jsonDecode(sent.body)['listen_type'], 'import');

      await client.playingNow(_track);
      final playing = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(playing['listen_type'], 'playing_now');
      expect(
        (playing['payload'] as List).single,
        isNot(contains('listened_at')),
      );
    });

    test('validates tokens and maps failures', () async {
      ListenBrainzClient respond(int status, String body) => ListenBrainzClient(
        token: 't',
        httpClient: MockClient((_) async => http.Response(body, status)),
      );
      expect(
        await respond(200, '{"valid":true,"user_name":"rob"}').validateToken(),
        'rob',
      );
      await expectLater(
        respond(200, '{"valid":false}').validateToken(),
        throwsFailure(ScrobbleFailure.auth),
      );
      await expectLater(
        respond(401, '{}').submit([_track]),
        throwsFailure(ScrobbleFailure.auth),
      );
      await expectLater(
        respond(429, '{}').submit([_track]),
        throwsFailure(ScrobbleFailure.retry),
      );
      await expectLater(
        respond(400, '{"error":"bad"}').submit([_track]),
        throwsFailure(ScrobbleFailure.rejected),
      );
    });
  });
}
