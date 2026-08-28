import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_query.dart';

class FakeLyricsLookup implements LyricsLookup {
  FakeLyricsLookup([this.result = LyricsLookupResult.missing]);

  LyricsLookupResult result;
  var calls = 0;
  LyricsQuery? lastQuery;

  @override
  Future<LyricsLookupResult> lookup(LyricsQuery query) async {
    calls++;
    lastQuery = query;
    return result;
  }
}
