import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

class SubsonicClient {
  SubsonicClient({required this.config, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final SubsonicServerConfig config;
  final http.Client _httpClient;

  static const apiVersion = '1.16.1';
  static const clientName = 'studio';

  /// Generates a random alphanumeric salt.
  static String generateSalt({int length = 10}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  /// Calculates MD5 token according to Subsonic specs: md5(password + salt).
  static String calculateToken(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    return md5.convert(bytes).toString();
  }

  Map<String, String> _buildAuthParams() {
    final salt = generateSalt();
    final token = calculateToken(config.password, salt);
    return {
      'u': config.username,
      't': token,
      's': salt,
      'v': apiVersion,
      'c': clientName,
      'f': 'json',
    };
  }

  Uri buildEndpointUri(String endpoint, [Map<String, String>? extraParams]) {
    final base = config.normalizedUrl;
    final path = base.endsWith('/rest')
        ? '$base/$endpoint'
        : '$base/rest/$endpoint';
    final queryParams = _buildAuthParams();
    if (extraParams != null) {
      queryParams.addAll(extraParams);
    }
    return Uri.parse(path).replace(queryParameters: queryParams);
  }

  Uri buildStreamUri(String songId) {
    return buildEndpointUri('stream', {'id': songId});
  }

  Uri? buildCoverArtUri(String? coverArtId, {int size = 300}) {
    if (coverArtId == null || coverArtId.isEmpty) return null;
    return buildEndpointUri('getCoverArt', {
      'id': coverArtId,
      'size': size.toString(),
    });
  }

  Future<Uint8List> fetchArtistImage(String imageUrl) async {
    final parsed = Uri.parse(imageUrl);
    final uri = (parsed.hasScheme
            ? parsed
            : Uri.parse(config.normalizedUrl).resolve(imageUrl))
        .replace(queryParameters: {
      ...parsed.queryParameters,
      ..._buildAuthParams(),
    });
    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('Artist image returned HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> _getJson(
    String endpoint, [
    Map<String, String>? params,
  ]) async {
    final uri = buildEndpointUri(endpoint, params);
    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Server returned HTTP ${response.statusCode}');
    }

    final decoded =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final subsonic = decoded['subsonic-response'] as Map<String, dynamic>?;

    if (subsonic == null) {
      throw Exception('Invalid Subsonic API response');
    }

    if (subsonic['status'] != 'ok') {
      final error = subsonic['error'] as Map<String, dynamic>?;
      final msg =
          error?['message'] as String? ?? 'Subsonic error ${error?['code']}';
      throw Exception(msg);
    }

    return subsonic;
  }

  Future<SubsonicConnectionInfo> ping() async {
    try {
      final response = await _getJson('ping');
      final type = response['type'] as String? ?? 'Subsonic';
      final version =
          response['serverVersion'] as String? ??
          response['version'] as String? ??
          apiVersion;
      return SubsonicConnectionInfo(
        status: SubsonicConnectionStatus.connected,
        serverType: type,
        serverVersion: version,
      );
    } catch (e) {
      return SubsonicConnectionInfo(
        status: SubsonicConnectionStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<List<SubsonicArtist>> getArtists() async {
    final response = await _getJson('getArtists');
    final artistsRoot = response['artists'] as Map<String, dynamic>?;
    if (artistsRoot == null) return [];

    final indexList = artistsRoot['index'] as List<dynamic>? ?? [];
    final result = <SubsonicArtist>[];

    for (final index in indexList) {
      if (index is! Map<String, dynamic>) continue;
      final artistList = index['artist'] as List<dynamic>? ?? [];
      for (final a in artistList) {
        if (a is Map<String, dynamic>) {
          result.add(SubsonicArtist.fromJson(a));
        }
      }
    }
    return result;
  }

  Future<List<SubsonicAlbum>> getArtist(String artistId) async {
    final response = await _getJson('getArtist', {'id': artistId});
    final artistData = response['artist'] as Map<String, dynamic>?;
    if (artistData == null) return [];

    final albumList = artistData['album'] as List<dynamic>? ?? [];
    return albumList
        .whereType<Map<String, dynamic>>()
        .map(SubsonicAlbum.fromJson)
        .toList();
  }

  Future<List<SubsonicSong>> getAlbum(String albumId) async {
    final response = await _getJson('getAlbum', {'id': albumId});
    final albumData = response['album'] as Map<String, dynamic>?;
    if (albumData == null) return [];

    final songList = albumData['song'] as List<dynamic>? ?? [];
    return songList
        .whereType<Map<String, dynamic>>()
        .map(SubsonicSong.fromJson)
        .toList();
  }

  Future<List<SubsonicAlbum>> getAlbumList({
    String type = 'alphabeticalByName',
    int size = 100,
    int offset = 0,
  }) async {
    final response = await _getJson('getAlbumList2', {
      'type': type,
      'size': size.toString(),
      'offset': offset.toString(),
    });
    final root = response['albumList2'] as Map<String, dynamic>?;
    if (root == null) return [];

    final albumList = root['album'] as List<dynamic>? ?? [];
    return albumList
        .whereType<Map<String, dynamic>>()
        .map(SubsonicAlbum.fromJson)
        .toList();
  }

  Future<List<SubsonicAlbum>> getAllAlbums({
    String type = 'alphabeticalByName',
    int pageSize = 500,
    int maxCount = 10000,
    void Function(int fetched)? onProgress,
  }) async {
    final all = <SubsonicAlbum>[];
    var offset = 0;
    while (all.length < maxCount) {
      final batch = await getAlbumList(
        type: type,
        size: pageSize,
        offset: offset,
      );
      if (batch.isEmpty) break;
      all.addAll(batch);
      onProgress?.call(all.length);
      if (batch.length < pageSize) break;
      offset += batch.length;
    }
    return all;
  }

  Future<List<SubsonicSong>> getRandomSongs({int size = 50}) async {
    final response = await _getJson('getRandomSongs', {
      'size': size.toString(),
    });
    final root = response['randomSongs'] as Map<String, dynamic>?;
    if (root == null) return [];

    final songList = root['song'] as List<dynamic>? ?? [];
    return songList
        .whereType<Map<String, dynamic>>()
        .map(SubsonicSong.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> search3(String query) async {
    final response = await _getJson('search3', {
      'query': query,
      'artistCount': '20',
      'albumCount': '20',
      'songCount': '30',
    });
    final root = response['searchResult3'] as Map<String, dynamic>? ?? {};

    final artists = (root['artist'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SubsonicArtist.fromJson)
        .toList();

    final albums = (root['album'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SubsonicAlbum.fromJson)
        .toList();

    final songs = (root['song'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SubsonicSong.fromJson)
        .toList();

    return {'artists': artists, 'albums': albums, 'songs': songs};
  }

  void dispose() {
    _httpClient.close();
  }
}
