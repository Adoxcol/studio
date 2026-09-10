import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

class _Lookup implements ArtistPictureLookup {
  _Lookup(this.result);
  Future<DownloadedArtistPicture?> Function() result;
  int calls = 0;
  @override
  Future<DownloadedArtistPicture?> fetch(ArtistImageRequest _) {
    calls++;
    return result();
  }

  @override
  void cancel() {}
  @override
  void close() {}
}

Future<void> _settled(ArtistPictureRepository repository) async {
  // Wait for real atomic file writes, not an assumed number of microtasks.
  for (var i = 0; i < 500; i++) {
    if ((await repository.get('Aria')).lookupState !=
        PictureLookupState.searching) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Artist work did not settle');
}

const _artist = ArtistImageRequest('Aria');
DownloadedArtistPicture _image() => DownloadedArtistPicture(
  Uint8List.fromList([1]),
  const PictureCredit(
    author: 'Author',
    license: 'Unknown',
    pageUrl: '',
    licenseUrl: '',
  ),
);

void main() {
  late Directory directory;
  late ArtistPictureRepository repository;
  late DateTime clock;
  late _Lookup lookup;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'studio-artist-cache-lifecycle-',
    );
    clock = DateTime.utc(2026, 8, 31);
    lookup = _Lookup(() async => _image());
    repository = ArtistPictureRepository(
      store: FileArtistPictureStore(directory),
      lookup: lookup,
      clock: () => clock,
      prepare: (bytes) async => bytes,
    );
  });
  tearDown(() async {
    repository.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> start() async {
    // Preload before starting so the test observes the initial searching state.
    await repository.get('Aria');
    repository.configure([_artist], enabled: true);
    await Future<void>.delayed(Duration.zero);
    await _settled(repository);
  }

  void restart() {
    repository.dispose();
    repository = ArtistPictureRepository(
      store: FileArtistPictureStore(directory),
      lookup: lookup,
      clock: () => clock,
      prepare: (bytes) async => bytes,
    );
  }

  test(
    'temporary failure survives restart as retryable failure and recovers at its deadline',
    () async {
      final deadline = clock.add(const Duration(minutes: 2));
      lookup.result = () async => throw ArtistServiceException(
        'musicbrainz.org',
        503,
        retryAfter: deadline,
      );
      await start();
      var saved = await FileArtistPictureStore(directory).load('aria');
      expect(saved.lookupState, PictureLookupState.failed);
      expect(saved.retryAfter, deadline);
      restart();
      lookup.result = () async => _image();
      await start();
      expect(lookup.calls, 1);
      clock = deadline;
      await start();
      expect(lookup.calls, 2);
      saved = await FileArtistPictureStore(directory).load('aria');
      expect(saved.lookupState, PictureLookupState.idle);
      expect(saved.remotePath, isNotNull);
      expect(saved.retryAfter, isNull);
    },
  );

  test(
    'confirmed miss survives restart separately and manual retry can replace it',
    () async {
      lookup.result = () async => null;
      await start();
      final saved = await FileArtistPictureStore(directory).load('aria');
      expect(saved.lookupState, PictureLookupState.missing);
      expect(saved.retryAfter, clock.add(const Duration(days: 7)));
      restart();
      await start();
      expect(lookup.calls, 1);
      lookup.result = () async => _image();
      repository.retry('Aria');
      await Future<void>.delayed(Duration.zero);
      await _settled(repository);
      expect(lookup.calls, 2);
      expect(
        (await FileArtistPictureStore(directory).load('aria')).lookupState,
        PictureLookupState.idle,
      );
    },
  );

  for (final fails in [false, true]) {
    test(
      'manual image survives late background result and restart (failure: $fails)',
      () async {
        final pending = Completer<DownloadedArtistPicture?>();
        lookup.result = () => pending.future;
        await repository.get('Aria');
        repository.configure([_artist], enabled: true);
        await Future<void>.delayed(Duration.zero);
        expect(lookup.calls, 1);
        await repository.setCustom('Aria', Uint8List.fromList([9]));
        final custom = (await repository.get('Aria')).customPath!;
        final completed = repository
            .watch('Aria')
            .firstWhere(
              (p) => fails
                  ? p.lookupState == PictureLookupState.failed
                  : p.remotePath != null,
            );
        if (fails) {
          pending.completeError(
            ArtistServiceException(
              'fanart.tv',
              503,
              retryAfter: clock.add(const Duration(minutes: 1)),
            ),
          );
        } else {
          pending.complete(_image());
        }
        await completed.timeout(const Duration(seconds: 5));
        restart();
        await start();
        final saved = await FileArtistPictureStore(directory).load('aria');
        expect(saved.path, custom);
        expect(saved.isCustom, isTrue);
        expect(await File(custom).readAsBytes(), [9]);
        if (!fails) {
          expect(saved.remotePath, isNot(custom));
          expect(await File(saved.remotePath!).readAsBytes(), [1]);
        }
        expect(lookup.calls, 1);
      },
    );
  }
}
