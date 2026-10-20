import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/scrobbling/data/scrobble_queue_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  test('ScrobbleSettings.toJson excludes secrets', () {
    const settings = ScrobbleSettings(
      lastFmApiKey: 'k',
      lastFmSecret: 'secret_val',
      lastFmSessionKey: 'session_val',
      lastFmUser: 'rj',
      listenBrainzToken: 'token_val',
      listenBrainzUser: 'rob',
    );
    final json = settings.toJson();
    expect(json.containsKey('lastFmSecret'), isFalse);
    expect(json.containsKey('lastFmSessionKey'), isFalse);
    expect(json.containsKey('listenBrainzToken'), isFalse);
    expect(json['lastFmApiKey'], 'k');
    expect(json['lastFmUser'], 'rj');
    expect(json['listenBrainzUser'], 'rob');
  });

  test('settings round-trip and tolerate a corrupt file', () async {
    final settingsFile = File(p.join(dir.path, 's.json'));
    final store = FileScrobbleSettingsStore(settingsFile);
    await store.init();
    expect(store.load().lastFmConnected, isFalse);
    store.save(
      const ScrobbleSettings(
        lastFmApiKey: 'k',
        lastFmSecret: 's',
        lastFmSessionKey: 'sk',
        lastFmUser: 'rj',
        listenBrainzToken: 't',
        listenBrainzUser: 'rob',
      ),
    );
    final loaded = store.load();
    expect(loaded.lastFmConnected, isTrue);
    expect(loaded.lastFmUser, 'rj');
    expect(loaded.listenBrainzConnected, isTrue);

    // Verify plaintext file does not contain secret strings
    final rawJson = settingsFile.readAsStringSync();
    expect(rawJson.contains('lastFmSecret'), isFalse);
    expect(rawJson.contains('lastFmSessionKey'), isFalse);
    expect(rawJson.contains('listenBrainzToken'), isFalse);

    settingsFile.writeAsStringSync('{not json');
    final store2 = FileScrobbleSettingsStore(settingsFile);
    await store2.init();
    expect(
      store2.load().listenBrainzConnected,
      isTrue,
    ); // because it's stored in mock secure storage
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
