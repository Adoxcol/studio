import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/data/prepare_artist_image.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FileArtistPictureStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'studio-artist-picture-test-',
    );
    store = FileArtistPictureStore(directory);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'disk cache survives restart, deduplicates bytes, preserves custom priority',
    () async {
      final remote = await store.saveImage(Uint8List.fromList([1, 2, 3]));
      expect(await store.saveImage(Uint8List.fromList([1, 2, 3])), remote);
      final custom = await store.saveImage(Uint8List.fromList([4, 5, 6]));
      const credit = PictureCredit(
        author: 'Photo author',
        license: 'CC0',
        pageUrl: 'https://commons.wikimedia.org/wiki/File:Example.png',
        licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
      );
      await store.save(
        'aria',
        ArtistPicture(customPath: custom, remotePath: remote, credit: credit),
      );
      final loaded = await FileArtistPictureStore(directory).load('aria');
      expect(loaded.path, custom);
      expect(loaded.remotePath, remote);
      expect(loaded.credit!.author, credit.author);
      await store.save(
        'aria',
        ArtistPicture(customPath: custom, remotePath: remote, hidden: true),
      );
      expect(
        (await FileArtistPictureStore(directory).load('aria')).hidden,
        isTrue,
      );
      expect(
        (await FileArtistPictureStore(directory).load('aria')).path,
        isNull,
      );
      expect(
        directory.listSync().where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'missing image files do not become permanently successful cache entries',
    () async {
      final path = await store.saveImage(Uint8List.fromList([1]));
      await store.save('aria', ArtistPicture(remotePath: path));
      await File(path).delete();
      final loaded = await store.load('aria');
      expect(loaded.needsLookup, isTrue);
      expect(loaded.path, isNull);
    },
  );

  test(
    'corrupt manifests recover and cannot reference paths outside the cache',
    () async {
      await store.save('aria', const ArtistPicture());
      final manifest = directory.listSync().whereType<File>().single;
      await manifest.writeAsString('{broken');
      expect((await store.load('aria')).needsLookup, isTrue);
      await manifest.writeAsString(
        jsonEncode({
          'custom': '../outside.png',
          'remote': r'C:\private\photo.png',
        }),
      );
      expect((await store.load('aria')).path, isNull);
    },
  );

  test(
    'retry deadlines survive restart and are distinct from custom choices',
    () async {
      final until = DateTime.utc(2026, 9, 8);
      await store.save(
        'aria',
        ArtistPicture(
          retryAfter: until,
          lookupState: PictureLookupState.failed,
        ),
      );
      final loaded = await store.load('aria');
      expect(loaded.retryAfter, until);
      expect(loaded.lookupState, PictureLookupState.failed);
    },
  );

  test(
    'stable lookup outcomes survive restart without inventing misses',
    () async {
      final until = DateTime.utc(2027);
      for (final state in PictureLookupState.values) {
        await store.save(
          'aria',
          ArtistPicture(lookupState: state, retryAfter: until),
        );
        final loaded = await FileArtistPictureStore(directory).load('aria');
        expect(
          loaded.lookupState,
          state == PictureLookupState.searching
              ? PictureLookupState.idle
              : state,
        );
        expect(
          loaded.retryAfter,
          state == PictureLookupState.failed ||
                  state == PictureLookupState.missing
              ? until
              : null,
        );
      }
      final remote = await store.saveImage(Uint8List.fromList([1]));
      await store.save('aria', ArtistPicture(remotePath: remote));
      final loaded = await FileArtistPictureStore(directory).load('aria');
      expect(loaded.lookupState, PictureLookupState.idle);
      expect(loaded.needsLookup, isFalse);
    },
  );

  test(
    'v4 failures and confirmed misses retain their distinct deadlines',
    () async {
      final until = DateTime.utc(2027);
      for (final failed in [false, true]) {
        await store.save('aria', const ArtistPicture());
        final file = directory.listSync().whereType<File>().single;
        await file.writeAsString(
          jsonEncode({
            'version': 4,
            'sourceRevision': 0,
            'failed': failed,
            'retryAfter': until.toIso8601String(),
          }),
        );
        final loaded = await FileArtistPictureStore(directory).load('aria');
        expect(
          loaded.lookupState,
          failed ? PictureLookupState.failed : PictureLookupState.missing,
        );
        expect(loaded.retryAfter, until);
      }
    },
  );

  test(
    'malformed optional metadata cannot discard either saved image slot',
    () async {
      final custom = await store.saveImage(Uint8List.fromList([9]));
      final remote = await store.saveImage(Uint8List.fromList([1]));
      await store.save(
        'aria',
        ArtistPicture(customPath: custom, remotePath: remote),
      );
      final file = directory.listSync().whereType<File>().singleWhere(
        (f) => f.path.endsWith('.json'),
      );
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json['credit'] = {'author': 42};
      json['retryAfter'] = 123;
      await file.writeAsString(jsonEncode(json));
      final loaded = await FileArtistPictureStore(directory).load('aria');
      expect(loaded.path, custom);
      expect(loaded.remotePath, remote);
      expect(loaded.credit, isNull);
      expect(loaded.needsLookup, isFalse);
      expect(await File(custom).readAsBytes(), [9]);
      expect(await File(remote).readAsBytes(), [1]);
    },
  );

  test(
    'unknown Commons credits survive saving and reopening the image cache',
    () async {
      final path = await store.saveImage(Uint8List.fromList([1, 2, 3]));
      const credit = PictureCredit(
        author: 'Author not supplied',
        license: 'License information not supplied',
        pageUrl: 'https://commons.wikimedia.org/wiki/File:Photo.jpg',
        licenseUrl: '',
      );
      await store.save('aria', ArtistPicture(remotePath: path, credit: credit));
      final loaded = await FileArtistPictureStore(directory).load('aria');
      expect(loaded.path, path);
      expect(loaded.needsLookup, isFalse);
      expect(loaded.credit!.toJson(), credit.toJson());
    },
  );

  test('bad custom imports leave an existing image untouched', () async {
    final repository = ArtistPictureRepository(store: store);
    addTearDown(repository.dispose);
    final existing = await store.saveImage(Uint8List.fromList([1]));
    await store.save('aria', ArtistPicture(customPath: existing));
    await expectLater(
      repository.setCustom('aria', Uint8List(0)),
      throwsFormatException,
    );
    expect((await repository.get('aria')).path, existing);
    await expectLater(
      prepareArtistImage(Uint8List(8 * 1024 * 1024 + 1)),
      throwsFormatException,
    );
    await expectLater(
      prepareArtistImage(Uint8List.fromList([1, 2, 3])),
      throwsA(anything),
    );
  });

  test(
    'new sources and legacy cache release negative deadlines but retain images',
    () async {
      var revision = 0;
      store = FileArtistPictureStore(directory, sourceRevision: () => revision);
      final path = await store.saveImage(Uint8List.fromList([9]));
      await store.save(
        'aria',
        ArtistPicture(customPath: path, retryAfter: DateTime.utc(2027)),
      );
      revision++;
      final updated = await store.load('aria');
      expect(updated.path, path);
      expect(updated.retryAfter, isNull);
      final file = directory.listSync().whereType<File>().singleWhere(
        (f) => f.path.endsWith('.json'),
      );
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json['version'] = 2;
      json['failed'] = true;
      await file.writeAsString(jsonEncode(json));
      final legacy = await store.load('aria');
      expect(legacy.path, path);
      expect(legacy.retryAfter, isNull);
    },
  );

  test('large valid images are decoded and cached at a bounded size', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawPaint(ui.Paint()..color = const ui.Color(0xff112233));
    final recording = recorder.endRecording();
    final image = await recording.toImage(1000, 500);
    final input = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    recording.dispose();
    final bytes = await prepareArtistImage(input);
    final codec = await ui.instantiateImageCodec(bytes);
    final output = (await codec.getNextFrame()).image;
    expect(output.width, 640);
    expect(output.height, 320);
    output.dispose();
    codec.dispose();
  });

  test(
    'Commons policy update retries old misses without replacing saved images',
    () async {
      final path = await store.saveImage(Uint8List.fromList([1, 2, 3]));
      final until = DateTime.utc(2027);
      await store.save(
        'aria',
        ArtistPicture(
          customPath: path,
          remotePath: path,
          hidden: true,
          retryAfter: until,
          lookupState: PictureLookupState.missing,
        ),
      );
      final manifest = directory.listSync().whereType<File>().singleWhere(
        (file) => file.path.endsWith('.json'),
      );
      final json =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      json['version'] = 3;
      await manifest.writeAsString(jsonEncode(json));
      final loaded = await store.load('aria');
      expect(loaded.retryAfter, isNull);
      expect(loaded.customPath, path);
      expect(loaded.remotePath, path);
      expect(loaded.hidden, isTrue);
      json['custom'] = null;
      json['remote'] = null;
      json['hidden'] = false;
      await manifest.writeAsString(jsonEncode(json));
      final missed = await store.load('aria');
      expect(missed.needsLookup, isTrue);
      expect(missed.retryAfter, isNull);
      // A service error under the old policy must still respect its retry time.
      json['failed'] = true;
      await manifest.writeAsString(jsonEncode(json));
      expect((await store.load('aria')).retryAfter, until);
    },
  );

  test(
    'artist download preference persists and old settings default to enabled',
    () async {
      final file = File('${directory.path}/appearance.json');
      final preferences = FileAppearanceStore(file);
      await file.writeAsString('{"mode":"auto"}');
      expect(preferences.load().fetchArtistPictures, isTrue);
      preferences.save(const AppearanceState(fetchArtistPictures: false));
      expect(FileAppearanceStore(file).load().fetchArtistPictures, isFalse);
      expect(
        preferences.load().copyWith(customHue: 240).fetchArtistPictures,
        isFalse,
      );
    },
  );
}
