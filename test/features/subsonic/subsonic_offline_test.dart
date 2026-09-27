import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/subsonic/data/subsonic_offline_store.dart';
import 'package:studio/features/subsonic/data/subsonic_playable_provider.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_providers.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/providers/playable_resolver.dart';

const _config = SubsonicServerConfig(
  serverUrl: 'https://music.example.com/',
  username: 'rob',
  password: 'secret',
);

final _audio = List<int>.generate(4096, (i) => i % 256);

http.StreamedResponse _file(
  List<int> bytes, {
  String type = 'audio/flac',
  String? disposition,
}) => http.StreamedResponse(
  Stream.fromIterable(
    bytes.length > 1000
        ? [bytes.sublist(0, 1000), bytes.sublist(1000)]
        : [bytes],
  ),
  200,
  contentLength: bytes.length,
  headers: {'content-type': type, 'content-disposition': ?disposition},
);

void main() {
  late Directory root;
  late SubsonicOfflineStore store;
  final server = SubsonicOfflineStore.serverKey(_config);

  setUp(() {
    root = Directory.systemTemp.createTempSync('studio-offline');
    store = SubsonicOfflineStore(root);
  });
  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  group('SubsonicOfflineStore', () {
    test('server key is stable, per account and never holds the password', () {
      expect(server, SubsonicOfflineStore.serverKey(_config));
      expect(
        SubsonicOfflineStore.serverKey(_config.copyWith(password: 'other')),
        server,
      );
      expect(
        SubsonicOfflineStore.serverKey(_config.copyWith(username: 'amy')),
        isNot(server),
      );
      expect(server, isNot(contains('secret')));
    });

    test('downloads to a complete file and survives a restart', () async {
      final progress = <int>[];
      final file = await store.download(
        server: server,
        songId: 'song-1',
        uri: Uri.parse('https://music.example.com/rest/download?id=song-1'),
        client: MockClient.streaming((request, _) async => _file(_audio)),
        onProgress: (received, _) => progress.add(received),
      );
      expect(p.extension(file.path), '.flac');
      expect(file.readAsBytesSync(), _audio);
      expect(progress, [1000, 4096]);
      expect(store.fileFor(server, 'song-1')?.path, file.path);

      final reopened = SubsonicOfflineStore(root);
      expect(reopened.downloadedIds(server), {'song-1'});
      expect(reopened.totalBytes(), 4096);
      expect(
        Directory(
          p.join(root.path, server),
        ).listSync().where((e) => e.path.endsWith('.part')),
        isEmpty,
      );
    });

    test('takes the extension from Content-Disposition first', () async {
      final file = await store.download(
        server: server,
        songId: 'a/b',
        uri: Uri.parse('https://x/rest/download'),
        client: MockClient.streaming(
          (_, _) async => _file(
            _audio,
            type: 'application/octet-stream',
            disposition: 'attachment; filename="01 Song.OPUS"',
          ),
        ),
      );
      expect(p.basename(file.path), 'a_b.opus');
    });

    test('a Subsonic error body is not saved as audio', () async {
      await expectLater(
        store.download(
          server: server,
          songId: 's',
          uri: Uri.parse('https://x/rest/download'),
          client: MockClient.streaming(
            (_, _) async => _file(
              utf8.encode('{"subsonic-response":{"status":"failed"}}'),
              type: 'application/json',
            ),
          ),
        ),
        throwsA(isA<OfflineDownloadFailed>()),
      );
      expect(store.fileFor(server, 's'), isNull);
    });

    test('cancelling mid-download leaves nothing behind', () async {
      final token = OfflineCancelToken();
      await expectLater(
        store.download(
          server: server,
          songId: 's',
          uri: Uri.parse('https://x/rest/download'),
          client: MockClient.streaming((_, _) async => _file(_audio)),
          cancel: token,
          onProgress: (_, _) => token.cancel(),
        ),
        throwsA(isA<OfflineDownloadCancelled>()),
      );
      expect(store.fileFor(server, 's'), isNull);
      expect(Directory(p.join(root.path, server)).listSync(), isEmpty);
    });

    test('remove and removeAll delete files and forget them', () async {
      for (final id in ['a', 'b']) {
        await store.download(
          server: server,
          songId: id,
          uri: Uri.parse('https://x/rest/download'),
          client: MockClient.streaming((_, _) async => _file(_audio)),
        );
      }
      final a = store.fileFor(server, 'a')!;
      store.remove(server, ['a']);
      expect(a.existsSync(), isFalse);
      expect(store.downloadedIds(server), {'b'});
      store.removeAll();
      expect(root.existsSync(), isFalse);
      expect(store.totalBytes(), 0);
    });

    test('ignores manifest entries that point outside the folder', () {
      final dir = Directory(p.join(root.path, server))..createSync();
      File(p.join(root.path, 'outside.flac')).writeAsBytesSync([1]);
      File(p.join(dir.path, 'index.json')).writeAsStringSync(
        jsonEncode({
          'evil': {'file': '../outside.flac', 'bytes': 1},
        }),
      );
      expect(SubsonicOfflineStore(root).fileFor(server, 'evil'), isNull);
    });
  });

  test('resolver plays the offline copy even without a connection', () async {
    final copy = File(p.join(root.path, 'song.flac'))..writeAsBytesSync([1]);
    final resolver = SubsonicPlayableProvider(
      clientGetter: () => null,
      offlineFile: (id) => id == 'song' ? copy : null,
    );
    final uri = await resolver.resolve(
      const TrackLocator(source: TrackLocator.subsonic, locator: 'song'),
    );
    expect(uri.scheme, 'file');
    expect(File.fromUri(uri).path, copy.absolute.path);
    await expectLater(
      resolver.resolve(
        const TrackLocator(source: TrackLocator.subsonic, locator: 'other'),
      ),
      throwsStateError,
    );
  });

  group('offlineDownloadsProvider', () {
    ProviderContainer container(http.Client client) {
      final c = ProviderContainer(
        overrides: [
          subsonicSettingsStoreProvider.overrideWithValue(
            MemorySubsonicSettingsStore(_config),
          ),
          subsonicOfflineStoreProvider.overrideWithValue(store),
          subsonicDownloadHttpClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> settle(ProviderContainer c) async {
      for (
        var i = 0;
        i < 50 && c.read(offlineDownloadsProvider).active.isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test(
      'downloads queued songs one at a time from the download endpoint',
      () async {
        final requested = <Uri>[];
        var running = 0;
        var maxRunning = 0;
        final c = container(
          MockClient.streaming((request, _) async {
            requested.add(request.url);
            running++;
            maxRunning = running > maxRunning ? running : maxRunning;
            await Future<void>.delayed(const Duration(milliseconds: 2));
            running--;
            return _file(_audio);
          }),
        );
        final notifier = c.read(offlineDownloadsProvider.notifier);
        notifier.download(['a', 'b', 'a']);
        expect(c.read(offlineDownloadsProvider).active.keys, ['a', 'b']);
        await settle(c);
        final state = c.read(offlineDownloadsProvider);
        expect(state.downloaded, {'a', 'b'});
        expect(state.totalBytes, 2 * _audio.length);
        expect(maxRunning, 1);
        expect(requested.map((u) => u.path).toSet(), {'/rest/download'});
        expect(requested.map((u) => u.queryParameters['id']), ['a', 'b']);
      },
    );

    test('records failures and lets a queued download be cancelled', () async {
      final gate = Completer<void>();
      final c = container(
        MockClient.streaming((request, _) async {
          await gate.future;
          return http.StreamedResponse(const Stream.empty(), 404);
        }),
      );
      final notifier = c.read(offlineDownloadsProvider.notifier);
      notifier.download(['a', 'b']);
      notifier.cancel('b');
      expect(c.read(offlineDownloadsProvider).active.keys, ['a']);
      gate.complete();
      await settle(c);
      final state = c.read(offlineDownloadsProvider);
      expect(state.downloaded, isEmpty);
      expect(state.failed.keys, ['a']);
      expect(state.failed['a'], contains('404'));
    });

    test('remove forgets a download', () async {
      final c = container(MockClient.streaming((_, _) async => _file(_audio)));
      final notifier = c.read(offlineDownloadsProvider.notifier);
      notifier.download(['a']);
      await settle(c);
      notifier.remove(['a']);
      expect(c.read(offlineDownloadsProvider).downloaded, isEmpty);
      expect(store.fileFor(server, 'a'), isNull);
    });

    test('is unavailable without a configured server', () {
      final c = ProviderContainer(
        overrides: [subsonicOfflineStoreProvider.overrideWithValue(store)],
      );
      addTearDown(c.dispose);
      expect(c.read(offlineDownloadsProvider).available, isFalse);
      c.read(offlineDownloadsProvider.notifier).download(['a']);
      expect(c.read(offlineDownloadsProvider).active, isEmpty);
    });

    test(
      'cancelling a download waiting on the server hides it at once',
      () async {
        final gate = Completer<http.StreamedResponse>();
        final c = container(MockClient.streaming((_, _) => gate.future));
        final notifier = c.read(offlineDownloadsProvider.notifier);
        notifier.download(['a']);
        await Future<void>.delayed(Duration.zero);
        notifier.cancel('a');
        expect(c.read(offlineDownloadsProvider).active, isEmpty);
        gate.complete(_file(_audio));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(c.read(offlineDownloadsProvider).downloaded, isEmpty);
        expect(store.fileFor(server, 'a'), isNull);
      },
    );
  });
}
