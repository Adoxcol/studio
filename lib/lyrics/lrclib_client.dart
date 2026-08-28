import 'dart:convert';
import 'dart:io';

import 'package:studio/core/app_info.dart';
import 'package:studio/lyrics/lyrics_query.dart';

class LrclibRecord {
  const LrclibRecord({
    this.syncedLyrics,
    this.plainLyrics,
    this.instrumental = false,
  });

  final String? syncedLyrics;
  final String? plainLyrics;
  final bool instrumental;
}

enum LyricsLookupStatus { found, missing, unavailable }

class LyricsLookupResult {
  const LyricsLookupResult(this.status, [this.record]);

  final LyricsLookupStatus status;
  final LrclibRecord? record;

  static const missing = LyricsLookupResult(LyricsLookupStatus.missing);
  static const unavailable = LyricsLookupResult(LyricsLookupStatus.unavailable);
}

abstract class LyricsLookup {
  Future<LyricsLookupResult> lookup(LyricsQuery query);
}

/// GET https://lrclib.net/api/get — no API key.
class LrclibClient implements LyricsLookup {
  LrclibClient({
    HttpClient? http,
    this.baseUrl = 'https://lrclib.net',
    this.userAgent = '$kAppName/$kAppVersion ($kAppHomepage)',
  }) : _http = http;

  final HttpClient? _http;
  final String baseUrl;
  final String userAgent;

  @override
  Future<LyricsLookupResult> lookup(LyricsQuery query) async {
    final params = <String, String>{
      'track_name': query.title,
      'artist_name': query.artist,
    };
    final album = query.album?.trim();
    if (album != null && album.isNotEmpty) {
      params['album_name'] = album;
    }
    final duration = query.durationSeconds;
    if (duration != null && duration >= 1 && duration <= 3600) {
      params['duration'] = '$duration';
    }
    final uri = Uri.parse('$baseUrl/api/get').replace(queryParameters: params);
    final client = _http ?? HttpClient();
    final owned = _http == null;
    try {
      client.userAgent = userAgent;
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await utf8.decodeStream(response);
      if (response.statusCode == 404) return LyricsLookupResult.missing;
      if (response.statusCode == 429 || response.statusCode != 200) {
        return LyricsLookupResult.unavailable;
      }
      final record = parseBody(body);
      if (record == null) return LyricsLookupResult.unavailable;
      return LyricsLookupResult(LyricsLookupStatus.found, record);
    } on Object {
      return LyricsLookupResult.unavailable;
    } finally {
      if (owned) client.close(force: true);
    }
  }

  static LrclibRecord? parseBody(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      return LrclibRecord(
        syncedLyrics: _string(json['syncedLyrics']),
        plainLyrics: _string(json['plainLyrics']),
        instrumental: json['instrumental'] == true,
      );
    } on Object {
      return null;
    }
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
