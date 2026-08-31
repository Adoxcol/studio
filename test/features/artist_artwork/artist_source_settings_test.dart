import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/artist_artwork/presentation/fanart_settings.dart';

class _FailingStore extends FanartSettingsStore {
  @override
  Future<void> save(FanartSettings settings) async =>
      throw const FileSystemException('unwritable');
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'studio-artist-source-test-',
    );
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'identity survives restart, normalizes clues, does not share other album matches',
    () async {
      const id = '12345678-1234-1234-1234-123456789abc';
      final first = ArtistIdentityStore(directory: directory);
      await first.save(
        const ArtistImageRequest('Aria', albums: ['Blue', 'Red']),
        id,
      );
      final restarted = ArtistIdentityStore(directory: directory);
      expect(
        await restarted.load(
          const ArtistImageRequest('ARIA', albums: ['red', 'BLUE']),
        ),
        id,
      );
      expect(
        await restarted.load(
          const ArtistImageRequest('Aria', albums: ['Other']),
        ),
        isNull,
      );
      expect(
        directory.listSync().where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'keys round-trip atomically and removal preserves new revision',
    () async {
      final file = File('${directory.path}/fanart.json');
      final store = FanartSettingsStore(file: file);
      const settings = FanartSettings(
        projectKey: 'synthetic-project',
        personalKey: 'synthetic-personal',
        revision: 1,
      );
      await store.save(settings);
      final restarted = FanartSettingsStore(file: file).load();
      expect(restarted.headers, settings.headers);
      expect(restarted.toString(), isNot(contains('synthetic')));
      await store.save(const FanartSettings(revision: 2));
      expect(FanartSettingsStore(file: file).load().enabled, isFalse);
      expect(await file.readAsString(), isNot(contains('synthetic')));
      expect(
        directory.listSync().where((f) => f.path.endsWith('.part')),
        isEmpty,
      );
    },
  );

  test(
    'settings trim keys, support personal alone, and reject header injection',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(fanartSettingsProvider.notifier);
      await notifier.save('', '  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ');
      final settings = container.read(fanartSettingsProvider);
      expect(settings.headers.keys, ['client-key']);
      expect(settings.revision, 1);
      await expectLater(
        notifier.save('invalid\r\nvalue', ''),
        throwsFormatException,
      );
      expect(
        identical(settings, container.read(fanartSettingsProvider)),
        isTrue,
      );
      await notifier.save('', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(container.read(fanartSettingsProvider).revision, 1);
    },
  );

  test('failed settings save does not publish unsaved credentials', () async {
    final container = ProviderContainer(
      overrides: [
        fanartSettingsStoreProvider.overrideWithValue(_FailingStore()),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(fanartSettingsProvider.notifier).save('a' * 32, ''),
      throwsA(isA<FileSystemException>()),
    );
    expect(container.read(fanartSettingsProvider).enabled, isFalse);
  });

  test(
    'Retry-After accepts seconds and HTTP dates, ignores malformed dates',
    () {
      final now = DateTime.utc(2026, 8, 31);
      expect(artistRetryAfter('120', now), now.add(const Duration(minutes: 2)));
      expect(
        artistRetryAfter('Mon, 31 Aug 2026 00:05:00 GMT', now),
        now.add(const Duration(minutes: 5)),
      );
      for (final value in [
        null,
        '-1',
        'junk',
        'Sun, 30 Aug 2026 00:05:00 GMT',
      ]) {
        expect(artistRetryAfter(value, now), isNull);
      }
      expect(
        artistRetryAfter('99999999', now),
        now.add(const Duration(days: 1)),
      );
    },
  );
}
