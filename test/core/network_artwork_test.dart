import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/core/network_artwork.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAXpeqz8AAAAASUVORK5CYII=',
);

String _cover(String id, String salt) =>
    'https://music.example.com/rest/getCoverArt?id=$id&size=300&u=me'
    '&t=token-$salt&s=$salt&v=1.16.1&c=studio&f=json';

void main() {
  late Directory dir;
  var requests = 0;

  MockClient server({int status = 200}) => MockClient((request) async {
    requests++;
    return http.Response.bytes(
      status == 200 ? _png : Uint8List(0),
      status,
      headers: {'content-type': 'image/png'},
    );
  });

  setUp(() {
    requests = 0;
    dir = Directory.systemTemp.createTempSync('artwork_cache_test');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('the key ignores the per-request salt and token', () {
    expect(
      stableArtworkKey(_cover('al-1', 'abc')),
      stableArtworkKey(_cover('al-1', 'xyz')),
    );
    expect(
      stableArtworkKey(_cover('al-1', 'abc')),
      isNot(stableArtworkKey(_cover('al-2', 'abc'))),
    );
    expect(stableArtworkKey(_cover('al-1', 'abc')), isNot(contains('s=abc')));
    expect(
      NetworkArtworkImage(_cover('al-1', 'abc')),
      NetworkArtworkImage(_cover('al-1', 'xyz')),
    );
  });

  test('tracks of one album share one download', () async {
    final cache = NetworkArtworkCache(directory: dir, client: server());
    await Future.wait([
      for (final salt in ['a', 'b', 'c', 'd'])
        cache.bytes(_cover('al-1', salt)),
    ]);
    expect(requests, 1);
  });

  test('covers survive a restart through the disk cache', () async {
    final first = NetworkArtworkCache(directory: dir, client: server());
    await first.bytes(_cover('al-1', 'a'));
    await pumpEventQueue();
    expect(requests, 1);

    final second = NetworkArtworkCache(directory: dir, client: server());
    final bytes = await second.bytes(_cover('al-1', 'other'));
    expect(bytes, _png);
    expect(requests, 1);
  });

  test('a failed download is not cached', () async {
    final failing = NetworkArtworkCache(
      directory: dir,
      client: server(status: 404),
    );
    await expectLater(
      failing.bytes(_cover('al-1', 'a')),
      throwsA(isA<NetworkImageLoadException>()),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('prune removes the oldest files once over the limit', () async {
    final cache = NetworkArtworkCache(directory: dir, maxBytes: 100);
    for (var i = 0; i < 4; i++) {
      File('${dir.path}/f$i')
        ..writeAsBytesSync(Uint8List(40))
        ..setLastModifiedSync(DateTime(2026, 1, 1 + i));
    }
    await cache.prune();
    final left = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(left, {'f3'});
  });

  testWidgets('decodes into an image', (tester) async {
    final cache = NetworkArtworkCache(client: server());
    final provider = NetworkArtworkImage(_cover('al-1', 'a'), cache: cache);
    await tester.runAsync(() async {
      final stream = provider.resolve(ImageConfiguration.empty);
      final info = await _first(stream);
      expect(info.image.width, 1);
      info.dispose();
    });
  });
}

Future<ImageInfo> _first(ImageStream stream) {
  final done = Completer<ImageInfo>();
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      done.complete(info);
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      done.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return done.future;
}
