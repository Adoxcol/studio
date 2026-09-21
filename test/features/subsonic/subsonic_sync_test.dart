import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';

void main() {
  group('Subsonic Database & Playlist Sync', () {
    late StudioDatabase db;

    setUp(() {
      db = StudioDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    test('replacePlaylistTracks updates entries in correct order', () async {
      // Create subsonic tracks
      final t1 = await db.getOrInsertTrack(
        TracksCompanion.insert(
          locator: 'subsonic://song-1',
          title: 'Track One',
          source: const Value(TrackLocator.subsonic),
        ),
      );
      final t2 = await db.getOrInsertTrack(
        TracksCompanion.insert(
          locator: 'subsonic://song-2',
          title: 'Track Two',
          source: const Value(TrackLocator.subsonic),
        ),
      );
      final t3 = await db.getOrInsertTrack(
        TracksCompanion.insert(
          locator: 'subsonic://song-3',
          title: 'Track Three',
          source: const Value(TrackLocator.subsonic),
        ),
      );

      final playlistId = await db.createPlaylist('Remote Hits');

      // Sync initial tracks [t1, t2]
      await db.replacePlaylistTracks(playlistId, [t1.id, t2.id]);
      var items = await db.playlistItems(playlistId);
      expect(items.length, 2);
      expect(items[0].track.id, t1.id);
      expect(items[1].track.id, t2.id);

      // Replace with updated tracks [t3, t1]
      await db.replacePlaylistTracks(playlistId, [t3.id, t1.id]);
      items = await db.playlistItems(playlistId);
      expect(items.length, 2);
      expect(items[0].track.id, t3.id);
      expect(items[1].track.id, t1.id);
    });

    test('batch insert preserves existing tracks and input order', () async {
      final existing = await db.getOrInsertTrack(
        TracksCompanion.insert(
          locator: 'song-2',
          title: 'Existing title',
          source: const Value(TrackLocator.subsonic),
        ),
      );
      final rows = await db.getOrInsertTracks([
        TracksCompanion.insert(
          locator: 'song-1',
          title: 'First',
          source: const Value(TrackLocator.subsonic),
        ),
        TracksCompanion.insert(
          locator: 'song-2',
          title: 'Ignored replacement',
          source: const Value(TrackLocator.subsonic),
        ),
      ]);

      expect(rows.map((track) => track.locator), ['song-1', 'song-2']);
      expect(rows.last.id, existing.id);
      expect(rows.last.title, 'Existing title');
    });
  });

  group('ArtistPictureRepository.saveRemote', () {
    late MemoryArtistPictureStore store;
    late ArtistPictureRepository repository;

    setUp(() {
      store = MemoryArtistPictureStore();
      repository = ArtistPictureRepository(
        store: store,
        prepare: (bytes) async => bytes,
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('saves remote image when no image exists', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await repository.saveRemote(
        'Daft Punk',
        fakeBytes,
        credit: const PictureCredit(
          author: 'Navidrome',
          license: 'Remote Library',
          pageUrl: '',
          licenseUrl: '',
        ),
      );

      final picture = await repository.get('Daft Punk');
      expect(picture.remotePath, isNotNull);
      expect(picture.path, picture.remotePath);
      expect(picture.credit?.author, 'Navidrome');
    });

    test('does not overwrite existing custom image', () async {
      final customBytes = Uint8List.fromList([9, 9, 9]);
      await repository.setCustom('Daft Punk', customBytes);

      final remoteBytes = Uint8List.fromList([1, 2, 3]);
      await repository.saveRemote('Daft Punk', remoteBytes);

      final picture = await repository.get('Daft Punk');
      expect(picture.isCustom, isTrue);
      expect(picture.remotePath, isNull);
    });

    test('does not overwrite hidden placeholder', () async {
      await repository.hide('Daft Punk');

      final remoteBytes = Uint8List.fromList([1, 2, 3]);
      await repository.saveRemote('Daft Punk', remoteBytes);

      final picture = await repository.get('Daft Punk');
      expect(picture.hidden, isTrue);
      expect(picture.path, isNull);
    });
  });

  group('SubsonicClient playlist and cover art fetching', () {
    const config = SubsonicServerConfig(
      serverUrl: 'https://music.example.com',
      username: 'user123',
      password: 'password',
    );

    test('getPlaylists parses response correctly', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/getPlaylists')) {
          return http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'playlists': {
                  'playlist': [
                    {
                      'id': 'pl-100',
                      'name': 'Electronic Beats',
                      'songCount': 5,
                      'duration': 1200,
                    },
                    {
                      'id': 'pl-101',
                      'name': 'Chillout Lounge',
                      'songCount': 10,
                      'duration': 2400,
                    },
                  ],
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final client = SubsonicClient(config: config, httpClient: mock);
      final playlists = await client.getPlaylists();
      expect(playlists.length, 2);
      expect(playlists[0].id, 'pl-100');
      expect(playlists[0].name, 'Electronic Beats');
      expect(playlists[1].id, 'pl-101');
      expect(playlists[1].name, 'Chillout Lounge');
      client.dispose();
    });

    test('getPlaylist parses tracks correctly', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/getPlaylist')) {
          expect(request.url.queryParameters['id'], 'pl-100');
          return http.Response(
            jsonEncode({
              'subsonic-response': {
                'status': 'ok',
                'playlist': {
                  'id': 'pl-100',
                  'name': 'Electronic Beats',
                  'entry': [
                    {
                      'id': 'song-1',
                      'title': 'One More Time',
                      'artist': 'Daft Punk',
                      'album': 'Discovery',
                      'duration': 320,
                    },
                  ],
                },
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final client = SubsonicClient(config: config, httpClient: mock);
      final songs = await client.getPlaylist('pl-100');
      expect(songs.length, 1);
      expect(songs.first.id, 'song-1');
      expect(songs.first.title, 'One More Time');
      expect(songs.first.artist, 'Daft Punk');
      client.dispose();
    });

    test('getCoverArtBytes returns binary image data on 200', () async {
      final imageBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
      ]); // PNG magic
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/getCoverArt')) {
          return http.Response.bytes(imageBytes, 200);
        }
        return http.Response('Not found', 404);
      });

      final client = SubsonicClient(config: config, httpClient: mock);
      final bytes = await client.getCoverArtBytes('art-123');
      expect(bytes, isNotNull);
      expect(bytes, imageBytes);
      client.dispose();
    });
  });
}
