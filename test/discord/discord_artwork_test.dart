import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_ids.dart';

void main() {
  test('parses a Freeimage direct upload URL', () {
    expect(
      parseFreeImageUploadUrl(
        '{"status_code":200,"image":{"url":"https://iili.io/abc123.jpg"}}',
      ),
      'https://iili.io/abc123.jpg',
    );
  });

  test('rejects malformed or insecure Freeimage responses', () {
    expect(parseFreeImageUploadUrl('not json'), isNull);
    expect(parseFreeImageUploadUrl('{}'), isNull);
    expect(
      parseFreeImageUploadUrl('{"image":{"url":"http://iili.io/a.jpg"}}'),
      isNull,
    );
  });

  test('falls back to the Studio asset when the URL is missing', () {
    expect(discordLargeImage(null), kDiscordLargeImageKey);
    expect(discordLargeImage(''), kDiscordLargeImageKey);
  });

  test('sends the raw HTTPS URL for Discord to proxy', () {
    const url = 'https://iili.io/a.jpg';
    expect(discordLargeImage(url), url);
  });

  test('posts Freeimage multipart fields and reads the direct URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final received = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, 'multipart/form-data');
      final body = await const Utf8Decoder(
        allowMalformed: true,
      ).bind(request).join();
      expect(body, contains('name="key"'));
      expect(body, contains('test-public-key'));
      expect(body, contains('name="action"'));
      expect(body, contains('upload'));
      expect(body, contains('name="source"; filename="artwork.jpg"'));
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          '{"status_code":200,"image":{"url":"https://iili.io/new.jpg"}}',
        );
      await request.response.close();
    });

    final url = await postToFreeImage(
      [0xff, 0xd8, 0xff, 0x00],
      'artwork.jpg',
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
      apiKey: 'test-public-key',
    );
    await received;
    expect(url, 'https://iili.io/new.jpg');
  });

  test('falls back to the Studio asset for a non-https URL', () {
    expect(
      discordLargeImage('http://insecure.example/a.jpg'),
      kDiscordLargeImageKey,
    );
    expect(
      discordLargeImage('https://user:secret@example.com/a.jpg'),
      kDiscordLargeImageKey,
    );
    expect(
      discordLargeImage('https://example.com/${'a' * 300}.jpg'),
      kDiscordLargeImageKey,
    );
  });

  test('uploader caches the HTTPS URL for the same file', () async {
    final dir = Directory.systemTemp.createTempSync('studio-discord-art');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cover = File('${dir.path}/cover.jpg')
      ..writeAsBytesSync(List<int>.filled(32, 7));
    var posts = 0;
    final uploader = FreeImageArtworkUploader(
      cacheFile: File('${dir.path}/discord-art.json'),
      poster: (bytes, filename) async {
        posts++;
        expect(filename, 'artwork.jpg');
        expect(bytes, isNotEmpty);
        return 'https://iili.io/cached.jpg';
      },
    );

    expect(await uploader.urlFor(cover.path), 'https://iili.io/cached.jpg');
    expect(await uploader.urlFor(cover.path), 'https://iili.io/cached.jpg');
    expect(posts, 1);

    final again = FreeImageArtworkUploader(
      cacheFile: File('${dir.path}/discord-art.json'),
      poster: (bytes, filename) async {
        posts++;
        return 'https://iili.io/should-not-run.jpg';
      },
    );
    expect(await again.urlFor(cover.path), 'https://iili.io/cached.jpg');
    expect(posts, 1);
  });

  test('old Catbox cache entries are discarded and replaced', () async {
    final dir = Directory.systemTemp.createTempSync('studio-discord-art');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cover = File('${dir.path}/cover.jpg')
      ..writeAsBytesSync(List<int>.filled(32, 7));
    final stat = cover.statSync();
    final key =
        '${cover.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    final cache = File('${dir.path}/discord-art.json')
      ..writeAsStringSync(
        '{${jsonEncode(key)}:"https://files.catbox.moe/broken.jpg"}',
      );
    var posts = 0;
    final uploader = FreeImageArtworkUploader(
      cacheFile: cache,
      poster: (bytes, filename) async {
        posts++;
        return 'https://iili.io/replacement.jpg';
      },
    );

    expect(uploader.cachedUrl(cover.path), isNull);
    expect(
      await uploader.urlFor(cover.path),
      'https://iili.io/replacement.jpg',
    );
    expect(posts, 1);
    expect(cache.readAsStringSync(), isNot(contains('files.catbox.moe')));
  });

  test('missing files do not upload', () async {
    final dir = Directory.systemTemp.createTempSync('studio-discord-art');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    var posts = 0;
    final uploader = FreeImageArtworkUploader(
      cacheFile: File('${dir.path}/cache.json'),
      poster: (bytes, filename) async {
        posts++;
        return 'https://iili.io/nope.jpg';
      },
    );
    expect(await uploader.urlFor('${dir.path}/missing.jpg'), isNull);
    expect(posts, 0);
  });

  test('failed uploads are not retried immediately', () async {
    final dir = Directory.systemTemp.createTempSync('studio-discord-art');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cover = File('${dir.path}/cover.jpg')
      ..writeAsBytesSync(List<int>.filled(32, 7));
    var posts = 0;
    final uploader = FreeImageArtworkUploader(
      cacheFile: File('${dir.path}/discord-art.json'),
      failCooldown: const Duration(minutes: 2),
      poster: (bytes, filename) async {
        posts++;
        throw StateError('nope');
      },
    );
    expect(await uploader.urlFor(cover.path), isNull);
    expect(await uploader.urlFor(cover.path), isNull);
    expect(posts, 1);
  });

  test('sniffs png vs jpeg for the upload filename', () {
    expect(
      imageFilenameFor([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0]),
      'artwork.png',
    );
    expect(imageFilenameFor([0xff, 0xd8, 0xff]), 'artwork.jpg');
    expect(imageContentType([0x89, 0x50, 0x4e, 0x47, 0, 0, 0, 0]), 'image/png');
  });
}
