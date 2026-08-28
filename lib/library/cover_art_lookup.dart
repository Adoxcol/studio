import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:studio/core/app_info.dart';

abstract class CoverArtLookup {
  Future<Uint8List?> fetch({required String artist, required String album});
}

/// Album artwork from Apple's iTunes Search API. No key.
class ITunesCoverArtLookup implements CoverArtLookup {
  ITunesCoverArtLookup({
    HttpClient? http,
    this.missFile,
    this.baseUrl = 'https://itunes.apple.com',
    this.userAgent = '$kAppName/$kAppVersion ($kAppHomepage)',
  }) : _http = http;

  static const _maxBytes = 8 * 1024 * 1024;

  final HttpClient? _http;
  final File? missFile;
  final String baseUrl;
  final String userAgent;

  Set<String>? _misses;

  @override
  Future<Uint8List?> fetch({
    required String artist,
    required String album,
  }) async {
    final who = artist.trim();
    final record = album.trim();
    if (who.isEmpty || record.isEmpty) return null;
    final key = _key(who, record);
    _loadMisses();
    if (_misses!.contains(key)) return null;

    final url = await _searchUrl(who, record);
    if (url == null) {
      _recordMiss(key);
      return null;
    }
    final bytes = await _download(url);
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  }

  Future<String?> _searchUrl(String artist, String album) async {
    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'term': '$artist $album',
        'media': 'music',
        'entity': 'album',
        'limit': '5',
      },
    );
    final body = await _getString(uri);
    if (body == null) return null;
    return artworkUrlFromSearch(body);
  }

  Future<String?> _getString(Uri uri) async {
    final client = _http ?? HttpClient();
    final owned = _http == null;
    try {
      client.userAgent = userAgent;
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) return null;
      return utf8.decodeStream(response);
    } on Object {
      return null;
    } finally {
      if (owned) client.close(force: true);
    }
  }

  Future<Uint8List?> _download(String url) async {
    final client = _http ?? HttpClient();
    final owned = _http == null;
    try {
      client.userAgent = userAgent;
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', userAgent);
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > _maxBytes) return null;
      }
      return builder.takeBytes();
    } on Object {
      return null;
    } finally {
      if (owned) client.close(force: true);
    }
  }

  void _loadMisses() {
    if (_misses != null) return;
    _misses = {};
    final file = missFile;
    if (file == null || !file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! List) return;
      for (final item in json) {
        if (item is String) _misses!.add(item);
      }
    } on Object {
      _misses = {};
    }
  }

  void _recordMiss(String key) {
    _misses ??= {};
    if (!_misses!.add(key)) return;
    final file = missFile;
    if (file == null) return;
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_misses!.toList()..sort()));
    } on Object {
      // Artwork cache is best-effort.
    }
  }

  static String _key(String artist, String album) {
    return '${artist.toLowerCase()}\u0001${album.toLowerCase()}';
  }

  static String? artworkUrlFromSearch(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final results = json['results'];
      if (results is! List || results.isEmpty) return null;
      for (final item in results) {
        if (item is! Map) continue;
        final raw = item['artworkUrl100'];
        if (raw is! String || raw.isEmpty) continue;
        return enlargeArtworkUrl(raw);
      }
      return null;
    } on Object {
      return null;
    }
  }

  static String enlargeArtworkUrl(String url) {
    return url.replaceFirst('100x100', '600x600');
  }
}
