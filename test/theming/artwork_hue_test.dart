import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/core/network_artwork.dart';
import 'package:studio/theming/artwork_hue.dart';
import 'package:studio/theming/oklch.dart';

void main() {
  test('hue cache is bounded LRU and reuses repeated artwork', () async {
    final calls = <String>[];
    final cache = ArtworkHueCache(
      capacity: 2,
      loader: (path) async {
        calls.add(path);
        return 20;
      },
    );
    addTearDown(cache.dispose);
    for (final path in ['a', 'b', 'a', 'c', 'a', 'b']) {
      expect(await cache.read(path), 20);
    }
    expect(calls, ['a', 'b', 'c', 'b']);
  });

  test('rapid skips decode only active and latest pending artwork', () async {
    final gate = Completer<double?>();
    final calls = <String>[];
    final cache = ArtworkHueCache(
      loader: (path) {
        calls.add(path);
        return path == 'a' ? gate.future : Future.value(30);
      },
    );
    addTearDown(cache.dispose);
    final a = cache.read('a');
    expect(cache.read('a'), same(a));
    final b = cache.read('b');
    final c = cache.read('c');
    expect(await b, isNull);
    gate.complete(10);
    expect(await a, 10);
    expect(await c, 30);
    expect(calls, ['a', 'c']);
  });

  test('failed extraction retries and disposal abandons queued work', () async {
    var calls = 0;
    final cache = ArtworkHueCache(
      loader: (_) async {
        if (++calls == 1) throw StateError('unavailable');
        return 42;
      },
    );
    expect(await cache.read('a'), isNull);
    expect(await cache.read('a'), 42);
    cache.dispose();
    expect(await cache.read('b'), isNull);
    expect(calls, 2);
  });

  Uint8List rgba(List<(int, int, int, int, int)> runs) {
    final bytes = BytesBuilder();
    for (final (count, r, g, b, a) in runs) {
      for (var i = 0; i < count; i++) {
        bytes.add([r, g, b, a]);
      }
    }
    return bytes.toBytes();
  }

  test('picks the hue of the most chromatic color', () async {
    final hue = await hueFromRgba(
      rgba([(3000, 90, 90, 90, 255), (600, 40, 90, 200, 255)]),
    );
    final blue = Oklch.fromColor(const Color(0xff285ac8)).h;
    expect(hue, closeTo(blue, 10));
  });

  test('greyscale and fully transparent artwork yield no hue', () async {
    expect(
      await hueFromRgba(
        rgba([(2000, 20, 20, 20, 255), (2000, 230, 230, 230, 255)]),
      ),
      isNull,
    );
    expect(await hueFromRgba(rgba([(500, 255, 0, 0, 0)])), isNull);
    expect(await hueFromRgba(Uint8List(0)), isNull);
  });

  test('signed copies of one remote cover share a result', () async {
    final calls = <String>[];
    final cache = ArtworkHueCache(
      loader: (path) async {
        calls.add(path);
        return 50;
      },
    );
    addTearDown(cache.dispose);
    const a =
        'https://music.example.com/rest/getCoverArt?id=al-1&u=me&t=x1&s=s1';
    const b =
        'https://music.example.com/rest/getCoverArt?id=al-1&u=me&t=x2&s=s2';

    expect(await cache.read(a), 50);
    expect(await cache.read(b), 50);
    expect(calls, [a]);
  });

  test('reads the hue of remote artwork', () async {
    // 4x4 solid blue PNG, served by the "Navidrome" server.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAEklEQVR4nGPQiDrxHxkzkC4AAMQIJJFpMddyAAAAAElFTkSuQmCC',
    );
    final network = NetworkArtworkCache(
      client: MockClient(
        (_) async => http.Response.bytes(
          png,
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
    );

    final hue = await hueFromArtwork(
      'https://music.example.com/rest/getCoverArt?id=al-1&s=a&t=b',
      network: network,
    );

    final blue = Oklch.fromColor(const Color(0xff285ac8)).h;
    expect(hue, closeTo(blue, 10));
  });
}
