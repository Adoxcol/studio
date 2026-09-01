import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:studio/features/artist_artwork/data/audio_db_artist_picture_source.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/data/artist_request_scheduler.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

const _mbid = 'cc197bad-dc9c-440d-a5b5-d52ba2e14234';
const _artist = ArtistImageRequest('Coldplay');
Map<String, Object?> _entry({
  String mbid = _mbid,
  String? url = 'https://r2.theaudiodb.com/images/media/artist/thumb/photo.jpg',
}) => {'strMusicBrainzID': mbid, 'idArtist': '111239', 'strArtistThumb': url};
Uint8List _json(Object? data) =>
    Uint8List.fromList(utf8.encode(jsonEncode(data)));

void main() {
  test('uses public-key MBID lookup and attributed HTTPS portrait', () async {
    final source = AudioDbArtistPictureSource();
    final urls = <Uri>[];
    final result = await source.fetch(_artist, _mbid, (uri, maxBytes) async {
      urls.add(uri);
      return uri.path.contains('artist-mb.php')
          ? _json({
              'artists': [_entry()],
            })
          : Uint8List.fromList([1, 2]);
    }, cancelled: () => false);
    expect(urls.first.path, '/api/v1/json/123/artist-mb.php');
    expect(urls.first.queryParameters, {'i': _mbid});
    expect(urls.last.host, 'r2.theaudiodb.com');
    expect(result!.bytes, [1, 2]);
    expect(result.credit.source, 'TheAudioDB');
    expect(result.credit.pageUrl, 'https://www.theaudiodb.com/artist/111239');
    expect(result.credit.license, contains('No image license supplied'));
  });

  test(
    'no entry and no portrait are misses; wrong artist and malformed JSON are errors',
    () async {
      final source = AudioDbArtistPictureSource();
      for (final data in [
        {'artists': null},
        {
          'artists': [_entry(url: null)],
        },
      ]) {
        expect(
          await source.fetch(
            _artist,
            _mbid,
            (_, _) async => _json(data),
            cancelled: () => false,
          ),
          isNull,
        );
      }
      for (final data in [
        {},
        [],
        {
          'artists': [null],
        },
        {'artists': 'broken'},
        {
          'artists': [_entry(mbid: 'other-id')],
        },
        {
          'artists': [_entry(), _entry()],
        },
      ]) {
        await expectLater(
          source.fetch(
            _artist,
            _mbid,
            (_, _) async => _json(data),
            cancelled: () => false,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'untrusted, non-HTTPS and credential-bearing image URLs are never downloaded',
    () async {
      for (final url in [
        'https://evil.example/photo.jpg',
        'http://r2.theaudiodb.com/images/media/artist/thumb/a.jpg',
        'https://r2.theaudiodb.com/images/media/artist/thumb/a.jpg?key=secret',
        'https://user@r2.theaudiodb.com/images/media/artist/thumb/a.jpg',
        'https://r2.theaudiodb.com/private/a.jpg',
      ]) {
        var calls = 0;
        final source = AudioDbArtistPictureSource();
        final result = await source.fetch(_artist, _mbid, (_, _) async {
          calls++;
          return _json({
            'artists': [_entry(url: url)],
          });
        }, cancelled: () => false);
        expect(calls, 1);
        expect(result, isNull);
      }
    },
  );

  test(
    '429 honors server deadline across artists without repeating network calls',
    () async {
      var clock = DateTime.utc(2026, 8, 31);
      final deadline = clock.add(const Duration(minutes: 3));
      var calls = 0;
      final source = AudioDbArtistPictureSource();
      final scheduler = ArtistRequestScheduler(
        audioDbSpacing: Duration.zero,
        clock: () => clock,
      );
      addTearDown(scheduler.close);
      Future<Uint8List> get(Uri _, int _) async {
        calls++;
        if (calls == 1) {
          throw ArtistServiceException(
            'www.theaudiodb.com',
            429,
            retryAfter: deadline,
          );
        }
        return _json({'artists': null});
      }

      for (var i = 0; i < 2; i++) {
        await expectLater(
          source.fetch(
            _artist,
            _mbid,
            (uri, maxBytes) => scheduler.run(
              uri,
              () => get(uri, maxBytes),
              artist: _artist.name,
              cancelled: () => false,
            ),
            cancelled: () => false,
          ),
          throwsA(
            isA<ArtistServiceException>().having(
              (e) => e.retryAfter,
              'deadline',
              deadline,
            ),
          ),
        );
      }
      expect(calls, 1);
      clock = deadline;
      expect(
        await source.fetch(
          _artist,
          _mbid,
          (uri, maxBytes) => scheduler.run(
            uri,
            () => get(uri, maxBytes),
            artist: _artist.name,
            cancelled: () => false,
          ),
          cancelled: () => false,
        ),
        isNull,
      );
      expect(calls, 2);
    },
  );

  test('cancellation never poisons the service cooldown', () async {
    var cancelled = false;
    final source = AudioDbArtistPictureSource();
    await expectLater(
      source.fetch(_artist, _mbid, (_, _) async {
        cancelled = true;
        throw http.RequestAbortedException();
      }, cancelled: () => cancelled),
      throwsA(isA<http.RequestAbortedException>()),
    );
    cancelled = false;
    expect(
      await source.fetch(
        _artist,
        _mbid,
        (_, _) async => _json({'artists': null}),
        cancelled: () => cancelled,
      ),
      isNull,
    );
  });

  test(
    'request pacing applies between artists and production defaults stay below 30/minute',
    () async {
      final source = AudioDbArtistPictureSource();
      final scheduler = ArtistRequestScheduler(
        audioDbSpacing: const Duration(milliseconds: 30),
      );
      addTearDown(scheduler.close);
      final times = <DateTime>[];
      for (var i = 0; i < 3; i++) {
        await source.fetch(
          _artist,
          _mbid,
          (uri, _) => scheduler.run(
            uri,
            () async {
              times.add(DateTime.now());
              return _json({'artists': null});
            },
            artist: _artist.name,
            cancelled: () => false,
          ),
          cancelled: () => false,
        );
      }
      expect(
        times[1].difference(times[0]).inMilliseconds,
        greaterThanOrEqualTo(29),
      );
      expect(
        times[2].difference(times[1]).inMilliseconds,
        greaterThanOrEqualTo(29),
      );
      expect(
        ArtistRequestScheduler().audioDbSpacing,
        greaterThan(const Duration(seconds: 2)),
      );
    },
  );
}
