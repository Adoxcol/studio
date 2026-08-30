import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/library/cover_art_lookup.dart';

void main() {
  test('artworkUrlFromSearch picks the first album image and enlarges it', () {
    const body = '''
{"resultCount":1,"results":[{"artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/Music/ab/100x100bb.jpg"}]}
''';
    expect(
      ITunesCoverArtLookup.artworkUrlFromSearch(body),
      'https://is1-ssl.mzstatic.com/image/thumb/Music/ab/600x600bb.jpg',
    );
  });

  test('artworkUrlFromSearch is null when iTunes has no results', () {
    expect(
      ITunesCoverArtLookup.artworkUrlFromSearch(
        '{"resultCount":0,"results":[]}',
      ),
      equals(null),
    );
    expect(ITunesCoverArtLookup.artworkUrlFromSearch('{'), equals(null));
  });

  group('ITunesCoverArtLookup network', () {
    test('returns null on connection error', () async {
      final lookup = ITunesCoverArtLookup(baseUrl: 'http://127.0.0.1:1');
      final result = await lookup.fetch(artist: 'Artist', album: 'Album');
      expect(result, isNull);
    });

    test('returns null on non-200 status code', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) {
        req.response.statusCode = HttpStatus.internalServerError;
        req.response.close();
      });

      final lookup = ITunesCoverArtLookup(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      final result = await lookup.fetch(artist: 'Artist', album: 'Album');
      expect(result, isNull);

      await server.close(force: true);
    });

    test('returns null on invalid JSON response', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) {
        req.response.statusCode = HttpStatus.ok;
        req.response.write('invalid json');
        req.response.close();
      });

      final lookup = ITunesCoverArtLookup(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      final result = await lookup.fetch(artist: 'Artist', album: 'Album');
      expect(result, isNull);

      await server.close(force: true);
    });

    test('returns artwork data on successful fetch', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) async {
        if (req.uri.path == '/search') {
          req.response.statusCode = HttpStatus.ok;
          req.response.write(
            '{"results": [{"artworkUrl100": "http://127.0.0.1:${server.port}/100x100.jpg"}]}',
          );
          await req.response.close();
        } else if (req.uri.path == '/600x600.jpg') {
          req.response.statusCode = HttpStatus.ok;
          req.response.add([1, 2, 3, 4]);
          await req.response.close();
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      });

      final lookup = ITunesCoverArtLookup(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );
      final result = await lookup.fetch(artist: 'Artist', album: 'Album');
      expect(result, equals([1, 2, 3, 4]));

      await server.close(force: true);
    });
  });
}
