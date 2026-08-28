import 'package:studio/lyrics/lrc.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_cache.dart';
import 'package:studio/lyrics/lyrics_query.dart';

class LyricsRepository {
  LyricsRepository({required this.lookup, required this.cache});

  final LyricsLookup lookup;
  final LyricsCache cache;

  Future<LyricsDocument> load(LyricsQuery query) async {
    final cached = cache.read(query);
    if (cached != null) return _documentFromRecord(cached.record);
    final result = await lookup.lookup(query);
    switch (result.status) {
      case LyricsLookupStatus.found:
        cache.write(query, result.record);
        return _documentFromRecord(result.record);
      case LyricsLookupStatus.missing:
        cache.write(query, null);
        return LyricsDocument.none;
      case LyricsLookupStatus.unavailable:
        return LyricsDocument.none;
    }
  }

  static LyricsDocument _documentFromRecord(LrclibRecord? record) {
    if (record == null) return LyricsDocument.none;
    if (record.instrumental) return LyricsDocument.instrumentalTrack;
    final synced = record.syncedLyrics;
    if (synced != null) {
      final parsed = LrcParser.parse(synced);
      if (parsed.hasLines) return parsed;
    }
    final plain = record.plainLyrics;
    if (plain != null) {
      final parsed = LrcParser.parse(plain);
      if (parsed.hasLines) return parsed;
    }
    return LyricsDocument.none;
  }
}
