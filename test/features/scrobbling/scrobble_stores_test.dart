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

  test('settings round-trip and tolerate a corrupt file', () async {
    final store = FileScrobbleSettingsStore(File(p.join(dir.path, 's.json')));
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
    File(p.join(dir.path, 's.json')).writeAsStringSync('{not json');
    final store2 = FileScrobbleSettingsStore(File(p.join(dir.path, 's.json')));
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
