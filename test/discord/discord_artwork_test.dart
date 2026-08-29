import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_ids.dart';

void main() {
  test('parses a catbox upload URL', () {
    expect(
      parseCatboxUploadUrl('https://files.catbox.moe/abc123.jpg'),
      'https://files.catbox.moe/abc123.jpg',
    );
    expect(
      parseCatboxUploadUrl('  https://files.catbox.moe/abc123.jpg  \n'),
      'https://files.catbox.moe/abc123.jpg',
    );
  });

  test('rejects a non-https catbox response', () {
    expect(parseCatboxUploadUrl('No request type given?'), isNull);
    expect(parseCatboxUploadUrl(''), isNull);
    expect(parseCatboxUploadUrl('http://insecure.example/a.jpg'), isNull);
  });

  test('falls back to the Studio asset when the URL is missing', () {
    expect(discordLargeImage(null), kDiscordLargeImageKey);
    expect(discordLargeImage(''), kDiscordLargeImageKey);
  });

  test('wraps an HTTPS cover in the mp:external media-proxy address', () {
    final asset = discordLargeImage('https://iili.io/a.jpg');
    expect(asset, startsWith('mp:external/'));
    expect(asset, endsWith('/https/iili.io/a.jpg'));
    // Same URL in, same asset out: a re-sent, unchanged cover must not look
    // like a new activity and rewrite the pipe every sync.
    expect(discordLargeImage('https://iili.io/a.jpg'), asset);
  });

  test('falls back to the Studio asset for a non-https URL', () {
    expect(
      discordLargeImage('http://insecure.example/a.jpg'),
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
    final uploader = CatboxArtworkUploader(
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

    final again = CatboxArtworkUploader(
      cacheFile: File('${dir.path}/discord-art.json'),
      poster: (bytes, filename) async {
        posts++;
        return 'https://iili.io/should-not-run.jpg';
      },
    );
    expect(await again.urlFor(cover.path), 'https://iili.io/cached.jpg');
    expect(posts, 1);
  });

  test('missing files do not upload', () async {
    final dir = Directory.systemTemp.createTempSync('studio-discord-art');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    var posts = 0;
    final uploader = CatboxArtworkUploader(
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
    final uploader = CatboxArtworkUploader(
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
