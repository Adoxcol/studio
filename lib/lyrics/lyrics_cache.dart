import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_query.dart';

class LyricsCacheHit {
  const LyricsCacheHit(this.record);

  /// `null` means a cached miss (LRCLIB had no match).
  final LrclibRecord? record;
}

abstract class LyricsCache {
  LyricsCacheHit? read(LyricsQuery query);
  void write(LyricsQuery query, LrclibRecord? record);
}

class MemoryLyricsCache implements LyricsCache {
  final _entries = <String, LyricsCacheHit>{};

  @override
  LyricsCacheHit? read(LyricsQuery query) => _entries[query.cacheKey];

  @override
  void write(LyricsQuery query, LrclibRecord? record) {
    _entries[query.cacheKey] = LyricsCacheHit(record);
  }
}

/// JSON files next to the library index, keyed by a fingerprint of the query.
class FileLyricsCache implements LyricsCache {
  FileLyricsCache(this.directory);

  final Directory directory;

  @override
  LyricsCacheHit? read(LyricsQuery query) {
    final file = _file(query);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (json['missing'] == true) return const LyricsCacheHit(null);
      return LyricsCacheHit(
        LrclibRecord(
          syncedLyrics: json['syncedLyrics'] as String?,
          plainLyrics: json['plainLyrics'] as String?,
          instrumental: json['instrumental'] == true,
        ),
      );
    } on Object {
      return null;
    }
  }

  @override
  void write(LyricsQuery query, LrclibRecord? record) {
    directory.createSync(recursive: true);
    _file(query).writeAsStringSync(
      jsonEncode({
        'missing': record == null,
        'instrumental': record?.instrumental ?? false,
        'syncedLyrics': record?.syncedLyrics,
        'plainLyrics': record?.plainLyrics,
      }),
    );
  }

  File _file(LyricsQuery query) {
    return File(p.join(directory.path, '${_fingerprint(query.cacheKey)}.json'));
  }

  static String _fingerprint(String value) {
    var hash = 0x811c9dc5;
    for (final code in value.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}
