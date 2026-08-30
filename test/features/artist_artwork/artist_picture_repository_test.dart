import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';

import '../../helpers/tracks.dart';

class _Lookup implements ArtistPictureLookup {
  final calls = <ArtistImageRequest>[];
  final pending = <Completer<DownloadedArtistPicture?>>[];
  int cancellations = 0;
  @override
  Future<DownloadedArtistPicture?> fetch(ArtistImageRequest artist) {
    calls.add(artist);
    final completer = Completer<DownloadedArtistPicture?>();
    pending.add(completer);
    return completer.future;
  }

  @override
  void cancel() {
    cancellations++;
    for (final item in pending) {
      if (!item.isCompleted) item.complete(null);
    }
  }

  @override
  void close() => cancel();
}

class _UnreadableStore extends MemoryArtistPictureStore {
  bool unreadable = true;
  @override
  Future<ArtistPicture> load(String key) {
    if (unreadable) throw StateError('Temporary disk read failure');
    return super.load(key);
  }
}

const _credit = PictureCredit(
  author: 'Photographer',
  license: 'CC BY-SA 4.0',
  pageUrl: 'https://commons.wikimedia.org/wiki/File:Test.jpg',
  licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
);
DownloadedArtistPicture _image(int value) =>
    DownloadedArtistPicture(Uint8List.fromList([value]), _credit);
Future<void> _flush() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _Lookup lookup;
  late MemoryArtistPictureStore store;
  late ArtistPictureRepository repository;
  late List<String> logs;
  final now = DateTime.utc(2026, 8, 31);
  final artists = [
    const ArtistImageRequest('Aria'),
    const ArtistImageRequest('Hal'),
  ];
  setUp(() {
    logs = [];
    lookup = _Lookup();
    store = MemoryArtistPictureStore();
    repository = ArtistPictureRepository(
      store: store,
      lookup: lookup,
      prepare: (bytes) async => bytes,
      clock: () => now,
      log: ArtistPictureLog(logs.add),
    );
  });
  tearDown(() => repository.dispose());

  test(
    'cached artist images are logged once, not on reads or repeated scans',
    () async {
      store.pictures['aria'] = const ArtistPicture(remotePath: 'cached.png');
      await repository.get('Aria');
      await repository.get('Aria');
      repository.configure([artists.first], enabled: true);
      await _flush();
      repository.configure([artists.first], enabled: true);
      await _flush();
      expect(logs.where((line) => line.contains('Cache hit')), hasLength(1));
      expect(
        logs.first,
        contains('["Aria"] Cache hit: using downloaded image.'),
      );
      expect(lookup.calls, isEmpty);
    },
  );

  test(
    'logs identify downloads, missing photos, error cause, backoff and manual changes',
    () async {
      repository.configure(artists, enabled: true);
      await _flush();
      lookup.pending.first.complete(_image(1));
      await _flush();
      lookup.pending.last.complete(null);
      await _flush();
      expect(logs, contains(contains('["Aria"] Searching online')));
      expect(
        logs,
        contains(contains('["Aria"] Downloaded and cached 1 bytes')),
      );
      expect(logs, contains(contains('["Hal"] No usable online photo')));
      repository.retry('Hal');
      await _flush();
      lookup.pending.last.completeError(StateError('offline'));
      await _flush();
      expect(
        logs,
        contains(
          contains('["Hal"] Failed while online lookup: Bad state: offline'),
        ),
      );
      expect(logs, contains(contains('Backing off until')));
      await repository.setCustom('Aria', Uint8List.fromList([9]));
      expect(logs.last, contains('Custom image saved'));
      repository.configure(artists, enabled: false);
      expect(logs.last, contains('Background fetching paused'));
    },
  );

  test(
    'a disk read failure cannot replace an existing custom picture',
    () async {
      repository.dispose();
      final disk = _UnreadableStore();
      disk.pictures['aria'] = const ArtistPicture(customPath: 'user-image.png');
      repository = ArtistPictureRepository(store: disk, lookup: lookup);
      repository.configure([artists.first], enabled: true);
      await _flush();
      expect(lookup.calls, isEmpty);
      expect(disk.pictures['aria']!.customPath, 'user-image.png');
      disk.unreadable = false;
      expect((await repository.get('Aria')).path, 'user-image.png');
    },
  );

  test(
    'all credits deduplicate case-insensitively and include album clues',
    () {
      final requests = artistImageRequests([
        testTrack(artist: 'Aria feat. Hal', album: 'Blue'),
        testTrack(id: 2, artist: 'ARIA', album: 'Red'),
        testTrack(id: 3, artist: null),
      ]).where((a) => a.searchable).toList();
      expect(requests.map((a) => a.key), ['aria', 'hal']);
      expect(requests.first.albums, ['Blue', 'Red']);
      expect(artistKey('  ARIA   Solvang '), 'aria solvang');
    },
  );

  test(
    'serial queue visits all artists without requiring an open widget',
    () async {
      repository.configure([
        ...artists,
        const ArtistImageRequest('ARIA'),
        const ArtistImageRequest('Unknown artist'),
      ], enabled: true);
      await _flush();
      expect(lookup.calls.map((a) => a.key), ['aria']);
      repository.configure(artists, enabled: true);
      lookup.pending.first.complete(_image(1));
      await _flush();
      expect(lookup.calls.map((a) => a.key), ['aria', 'hal']);
      lookup.pending.last.complete(_image(2));
      await _flush();
      repository.configure(artists, enabled: true);
      await _flush();
      expect(lookup.calls, hasLength(2));
      expect((await repository.get('Aria')).remotePath, isNotNull);
      expect((await repository.get('Hal')).remotePath, isNotNull);
    },
  );

  test(
    'custom image wins over an in-flight download without waiting',
    () async {
      repository.configure([artists.first], enabled: true);
      await _flush();
      await repository.setCustom('ARIA', Uint8List.fromList([9]));
      final custom = (await repository.get('Aria')).path;
      expect(custom, isNotNull);
      expect(lookup.pending.single.isCompleted, isFalse);
      lookup.pending.single.complete(_image(1));
      await _flush();
      final picture = await repository.get('Aria');
      expect(picture.path, custom);
      expect(picture.remotePath, isNot(custom));
      await repository.useAutomatic('Aria');
      expect((await repository.get('Aria')).path, picture.remotePath);
    },
  );

  test('explicit placeholder survives a late download and rescan', () async {
    repository.configure([artists.first], enabled: true);
    await _flush();
    await repository.hide('Aria');
    lookup.pending.single.complete(_image(1));
    await _flush();
    repository.configure([artists.first], enabled: true);
    await _flush();
    expect((await repository.get('Aria')).path, isNull);
    expect((await repository.get('Aria')).hidden, isTrue);
    expect(lookup.calls, hasLength(1));
    await repository.useAutomatic('Aria');
    expect((await repository.get('Aria')).path, isNotNull);
  });

  test(
    'disabling cancels work; cached/custom images remain available',
    () async {
      await repository.setCustom('Hal', Uint8List.fromList([9]));
      repository.configure(artists, enabled: true);
      await _flush();
      repository.configure(artists, enabled: false);
      await _flush();
      expect(lookup.cancellations, 1);
      expect(lookup.calls, hasLength(1));
      expect((await repository.get('Hal')).isCustom, isTrue);
      expect(
        (await repository.get('Aria')).lookupState,
        PictureLookupState.idle,
      );
      repository.configure(artists, enabled: true);
      await _flush();
      expect(lookup.calls, hasLength(2));
    },
  );

  test('misses persist with expiry; errors back off the whole queue', () async {
    repository.configure(artists, enabled: true);
    await _flush();
    lookup.pending.first.complete(null);
    await _flush();
    final missing = await repository.get('Aria');
    expect(missing.lookupState, PictureLookupState.missing);
    expect(missing.retryAfter, now.add(const Duration(days: 7)));
    expect(store.pictures['aria']!.retryAfter, missing.retryAfter);
    lookup.pending.last.completeError(StateError('offline'));
    await _flush();
    expect(
      (await repository.get('Hal')).lookupState,
      PictureLookupState.failed,
    );
    repository.configure([
      ...artists,
      const ArtistImageRequest('New artist'),
    ], enabled: true);
    await _flush();
    expect(lookup.calls, hasLength(2));
  });

  test('manual retry bypasses a miss but not an existing image', () async {
    repository.configure([artists.first], enabled: true);
    await _flush();
    lookup.pending.single.complete(null);
    await _flush();
    repository.retry('Aria');
    await _flush();
    expect(lookup.calls, hasLength(2));
    lookup.pending.last.complete(_image(1));
    await _flush();
    repository.retry('Aria');
    await _flush();
    expect(lookup.calls, hasLength(2));
  });

  test('provider refresh retries misses and retains custom images', () async {
    await repository.setCustom('Hal', Uint8List.fromList([9]));
    repository.configure(artists, enabled: true);
    await _flush();
    lookup.pending.single.complete(null);
    await _flush();
    await repository.refreshSources();
    await _flush();
    expect(lookup.calls.map((a) => a.key), ['aria', 'aria']);
    expect((await repository.get('Hal')).isCustom, isTrue);
  });

  test(
    'an unusable artist response cannot block the rest of the library',
    () async {
      repository.configure(artists, enabled: true);
      await _flush();
      lookup.pending.first.completeError(
        const FormatException('Bad image data'),
      );
      await _flush();
      expect(lookup.calls.map((a) => a.key), ['aria', 'hal']);
      expect(
        (await repository.get('Aria')).lookupState,
        PictureLookupState.failed,
      );
    },
  );

  test(
    'service deadline retries the interrupted artist first, not an hour later',
    () async {
      repository.dispose();
      var clock = now;
      repository = ArtistPictureRepository(
        store: store,
        lookup: lookup,
        prepare: (b) async => b,
        clock: () => clock,
      );
      repository.configure(artists, enabled: true);
      await _flush();
      final deadline = now.add(const Duration(minutes: 2));
      lookup.pending.first.completeError(
        ArtistServiceException('musicbrainz.org', 503, retryAfter: deadline),
      );
      await _flush();
      expect((await repository.get('Aria')).retryAfter, deadline);
      clock = deadline;
      repository.configure(artists, enabled: true);
      await _flush();
      expect(lookup.calls.map((a) => a.key), ['aria', 'aria']);
      lookup.pending.last.complete(_image(1));
      await _flush();
      expect(lookup.calls.map((a) => a.key), ['aria', 'aria', 'hal']);
    },
  );

  test(
    'subscribers see custom imports, and late results after dispose are ignored',
    () async {
      final events = <ArtistPicture>[];
      final sub = repository.watch('ARIA').listen(events.add);
      await _flush();
      await repository.setCustom('Aria', Uint8List.fromList([9]));
      await _flush();
      expect(events.last.isCustom, isTrue);
      await sub.cancel();
      repository.configure([artists.last], enabled: true);
      await _flush();
      repository.dispose();
      await _flush();
      expect(store.pictures.containsKey('hal'), isFalse);
    },
  );
}
