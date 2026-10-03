import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/scrobbling/data/scrobble_queue_store.dart';
import 'package:studio/features/scrobbling/data/scrobble_settings_store.dart';
import 'package:studio/features/scrobbling/domain/scrobble_settings.dart';
import 'package:studio/features/scrobbling/domain/scrobble_track.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('studio-scrobble');
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('settings round-trip and tolerate a corrupt file', () async {
    final file = File(p.join(dir.path, 's.json'));
    final store = SecureScrobbleSettingsStore(legacyFile: file);
    await store.init();
    expect((await store.load()).lastFmConnected, isFalse);

    await store.save(
      const ScrobbleSettings(
        lastFmApiKey: 'k',
        lastFmSecret: 's',
        lastFmSessionKey: 'sk',
        lastFmUser: 'rj',
        listenBrainzToken: 't',
        listenBrainzUser: 'rob',
      ),
    );

    final loaded = await store.load();
    expect(loaded.lastFmConnected, isTrue);
    expect(loaded.lastFmUser, 'rj');
    expect(loaded.listenBrainzConnected, isTrue);

    final persisted = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(persisted.containsKey('lastFmSecret'), isFalse);
    expect(persisted.containsKey('lastFmSessionKey'), isFalse);
    expect(persisted.containsKey('listenBrainzToken'), isFalse);

    file.writeAsStringSync('{not json');
    final store2 = SecureScrobbleSettingsStore(legacyFile: file);
    await store2.init();
    expect((await store2.load()).listenBrainzConnected, isTrue);
  });

  test('migrates legacy file secrets into secure storage', () async {
    final file = File(p.join(dir.path, 's.json'));
    final store = SecureScrobbleSettingsStore(legacyFile: file);

    file.writeAsStringSync(
      jsonEncode({
        'lastFmApiKey': 'legacy_k',
        'lastFmSecret': 'legacy_s',
        'lastFmSessionKey': 'legacy_sk',
        'lastFmUser': 'legacy_user',
      }),
    );

    final loaded = await store.load();
    expect(loaded.lastFmUser, 'legacy_user');
    expect(loaded.lastFmSecret, 'legacy_s');

    final persisted = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(persisted.containsKey('lastFmSecret'), isFalse);
    expect(persisted.containsKey('lastFmSessionKey'), isFalse);
  });

  test('queue round-trips and skips malformed entries', () {
    final file = File(p.join(dir.path, 'q.json'));
    final store = FileScrobbleQueueStore(file);
    final track = ScrobbleTrack(
      artist: 'A',
      title: 'T',
      album: 'L',
      duration: const Duration(seconds: 90),
      startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    store.save({
      'lastfm': [track],
      'listenbrainz': [],
    });
    expect(store.load(), {
      'lastfm': [track],
    });
    file.writeAsStringSync(
      '{"lastfm":[{"artist":"A"},${'{"artist":"A","title":"T","startedAt":"2026-01-02T03:04:05.000Z"}'}]}',
    );
    expect(store.load()['lastfm'], hasLength(1));
  });
}
