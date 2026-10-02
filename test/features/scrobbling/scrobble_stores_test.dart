import 'dart:io';
import 'dart:convert';

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

  test('settings round-trip with secure storage', () async {
    final file = File(p.join(dir.path, 's.json'));
    final store = SecureScrobbleSettingsStore(legacyFile: file);
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

    // Malformed JSON should yield defaults
    FlutterSecureStorage.setMockInitialValues({
      'scrobble_settings': '{not json',
    });
    expect((await store.load()).listenBrainzConnected, isFalse);
  });

  test('migrates legacy file to secure storage and deletes it', () async {
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
    expect(file.existsSync(), isFalse);

    // Check it's in storage
    const storage = FlutterSecureStorage();
    final inStorage = await storage.read(key: 'scrobble_settings');
    expect(inStorage, isNotNull);
    expect(jsonDecode(inStorage!)['lastFmUser'], 'legacy_user');
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
