import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/state/library_providers.dart';

const _config = SubsonicServerConfig(
  serverUrl: 'https://music.example.com',
  username: 'user',
  password: 'secret',
);

http.Response _ok(Map<String, Object?> body) => http.Response(
  jsonEncode({
    'subsonic-response': {'status': 'ok', ...body},
  }),
  200,
);

/// A server with [albums] albums of [songsPerAlbum] songs each.
MockClient _server({required int albums, int songsPerAlbum = 3}) =>
    MockClient(_handler(albums: albums, songsPerAlbum: songsPerAlbum));

MockClientHandler _handler({required int albums, int songsPerAlbum = 3}) {
  return (request) async {
    final path = request.url.path;
    final params = request.url.queryParameters;
    if (path.endsWith('/getAlbumList2')) {
      final offset = int.parse(params['offset'] ?? '0');
      final size = int.parse(params['size'] ?? '500');
      final end = (offset + size).clamp(0, albums);
      return _ok({
        'albumList2': {
          'album': [
            for (var i = offset; i < end; i++)
              {'id': 'al-$i', 'name': 'Album $i', 'artist': 'Artist'},
          ],
        },
      });
    }
    if (path.endsWith('/getAlbum')) {
      final id = params['id']!;
      return _ok({
        'album': {
          'id': id,
          'name': 'Album $id',
          'song': [
            for (var s = 0; s < songsPerAlbum; s++)
              {
                'id': '$id-song-$s',
                'title': 'Song $s',
                'album': 'Album $id',
                'artist': 'Artist',
                'track': s + 1,
                'duration': 200,
              },
          ],
        },
      });
    }
    if (path.endsWith('/getPlaylists')) {
      return _ok({
        'playlists': {'playlist': <Object>[]},
      });
    }
    if (path.endsWith('/getArtists')) {
      return _ok({
        'artists': {'index': <Object>[]},
      });
    }
    return http.Response('Not found', 404);
  };
}

void main() {
  late StudioDatabase db;
  ProviderContainer? container;

  ProviderContainer containerFor(MockClient server) {
    final client = SubsonicClient(config: _config, httpClient: server);
    final c = ProviderContainer(
      overrides: [
        studioDatabaseProvider.overrideWithValue(db),
        subsonicClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(client.dispose);
    return c;
  }

  setUp(() {
    db = StudioDatabase.memory();
  });

  tearDown(() async {
    container?.dispose();
    container = null;
    await db.close();
  });

  test('scan stores every track and reports final counts', () async {
    container = containerFor(_server(albums: 12, songsPerAlbum: 4));

    await container!.read(subsonicScanProvider.notifier).startScan();

    final state = container!.read(subsonicScanProvider);
    expect(state.error, isNull);
    expect(state.isScanning, isFalse);
    expect(state.isCompleted, isTrue);
    expect(state.totalAlbums, 12);
    expect(state.currentAlbum, 12);
    expect(state.totalTracks, 48);

    final stored = await db.allTracks(source: TrackLocator.subsonic);
    expect(stored, hasLength(48));
  });

  test('scan writes tracks in batches, not once per album', () async {
    container = containerFor(_server(albums: 40));
    var trackWrites = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.tracks))
        .listen((_) => trackWrites++);
    addTearDown(sub.cancel);

    await container!.read(subsonicScanProvider.notifier).startScan();
    await pumpEventQueue();

    expect(await db.allTracks(source: TrackLocator.subsonic), hasLength(120));
    // 40 albums finish well inside one flush window.
    expect(trackWrites, 1);
  });

  test('scan throttles progress updates', () async {
    container = containerFor(_server(albums: 60));
    var updates = 0;
    final sub = container!.listen(subsonicScanProvider, (_, _) => updates++);
    addTearDown(sub.close);

    await container!.read(subsonicScanProvider.notifier).startScan();

    // Unthrottled this was at least two updates per album.
    expect(updates, lessThan(60));
    expect(container!.read(subsonicScanProvider).totalTracks, 180);
  });

  test('a cancelled scan keeps the tracks it already fetched', () async {
    final gate = Completer<void>();
    var albumsServed = 0;
    final inner = _handler(albums: 10);
    container = containerFor(
      MockClient((request) async {
        if (request.url.path.endsWith('/getAlbum') && ++albumsServed == 4) {
          await gate.future;
        }
        return inner(request);
      }),
    );

    final notifier = container!.read(subsonicScanProvider.notifier);
    final scan = notifier.startScan();
    while (albumsServed < 4) {
      await Future<void>.delayed(Duration.zero);
    }
    notifier.cancelScan();
    gate.complete();
    await scan;

    final stored = await db.allTracks(source: TrackLocator.subsonic);
    expect(stored, hasLength(9));
    expect(container!.read(subsonicScanProvider).isScanning, isFalse);
  });

  test('subsonic writes do not re-emit the local tracks stream', () async {
    await db.upsertTrack(
      TracksCompanion.insert(locator: '/music/a.flac', title: 'Local'),
    );
    final emissions = <List<Track>>[];
    final sub = db.watchTracks().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(emissions, hasLength(1));

    await db.insertTracksIfNotExists([
      TracksCompanion.insert(
        locator: 'remote-1',
        title: 'Remote',
        source: const Value(TrackLocator.subsonic),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(emissions, hasLength(1));

    await db.upsertTrack(
      TracksCompanion.insert(locator: '/music/b.flac', title: 'Local 2'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(emissions, hasLength(2));
    expect(emissions.last, hasLength(2));
  });
}
