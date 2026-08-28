import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_cache.dart';
import 'package:studio/lyrics/lyrics_query.dart';
import 'package:studio/lyrics/lyrics_repository.dart';

import 'fake_lyrics_lookup.dart';

void main() {
  const query = LyricsQuery(
    title: 'I Want to Live',
    artist: 'Borislav Slavov',
    album: 'Baldur\'s Gate 3',
    durationSeconds: 233,
  );

  test('parseBody reads synced and plain fields', () {
    const body = '''
{"instrumental":false,"syncedLyrics":"[00:01.00] Hello","plainLyrics":"Hello"}
''';
    final record = LrclibClient.parseBody(body)!;
    expect(record.instrumental, isFalse);
    expect(record.syncedLyrics, '[00:01.00] Hello');
    expect(record.plainLyrics, 'Hello');
  });

  test('parseBody returns null for invalid JSON', () {
    expect(LrclibClient.parseBody('{'), equals(null));
  });

  test('repository prefers synced lyrics and caches the record', () async {
    final lookup = FakeLyricsLookup(
      const LyricsLookupResult(
        LyricsLookupStatus.found,
        LrclibRecord(syncedLyrics: '[00:01.00] Hello\n[00:05.00] World'),
      ),
    );
    final cache = MemoryLyricsCache();
    final repo = LyricsRepository(lookup: lookup, cache: cache);
    final first = await repo.load(query);
    expect(first.synced, isTrue);
    expect(first.lines.map((l) => l.text).toList(), ['Hello', 'World']);
    expect(lookup.calls, 1);

    lookup.result = LyricsLookupResult.unavailable;
    final second = await repo.load(query);
    expect(second.lines.map((l) => l.text).toList(), ['Hello', 'World']);
    expect(lookup.calls, 1);
  });

  test('cached misses skip the network', () async {
    final lookup = FakeLyricsLookup(LyricsLookupResult.missing);
    final cache = MemoryLyricsCache();
    final repo = LyricsRepository(lookup: lookup, cache: cache);
    expect((await repo.load(query)).missing, isTrue);
    expect((await repo.load(query)).missing, isTrue);
    expect(lookup.calls, 1);
  });

  test('unavailable results are not cached', () async {
    final lookup = FakeLyricsLookup(LyricsLookupResult.unavailable);
    final cache = MemoryLyricsCache();
    final repo = LyricsRepository(lookup: lookup, cache: cache);
    await repo.load(query);
    await repo.load(query);
    expect(lookup.calls, 2);
  });

  test('file cache round-trips a miss and a record', () {
    final dir = Directory.systemTemp.createTempSync('studio-lyrics');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cache = FileLyricsCache(dir);
    expect(cache.read(query), equals(null));
    cache.write(query, null);
    expect(cache.read(query)?.record, equals(null));
    cache.write(
      query,
      const LrclibRecord(plainLyrics: 'Hello', instrumental: false),
    );
    expect(cache.read(query)?.record?.plainLyrics, 'Hello');
  });
}
