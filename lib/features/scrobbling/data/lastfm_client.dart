import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/domain/scrobble_track.dart';

class LastFmSession {
  const LastFmSession({required this.key, required this.user});
  final String key;
  final String user;
}

/// Last.fm Scrobbling API 2.0 with desktop (token) authentication.
class LastFmClient {
  LastFmClient({
    required this.apiKey,
    required this.secret,
    http.Client? httpClient,
    Uri? endpoint,
  }) : _http = httpClient ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('https://ws.audioscrobbler.com/2.0/');

  final String apiKey;
  final String secret;
  final http.Client _http;
  final Uri _endpoint;

  static const _timeout = Duration(seconds: 20);

  /// Error codes meaning the key, token or session is not usable.
  static const _authErrors = {4, 9, 10, 14, 15, 26};

  /// Error codes meaning "try again later".
  static const _retryErrors = {8, 11, 16, 29};

  /// Last.fm's request signature: md5 of the sorted params plus the secret.
  static String sign(Map<String, String> params, String secret) {
    final keys = params.keys.where((k) => k != 'format' && k != 'callback');
    final sorted = keys.toList()..sort();
    final buffer = StringBuffer();
    for (final key in sorted) {
      buffer
        ..write(key)
        ..write(params[key]);
    }
    buffer.write(secret);
    return md5.convert(utf8.encode(buffer.toString())).toString();
  }

  Future<String> getToken() async {
    final json = await _call({'method': 'auth.getToken'});
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const ScrobbleException(
        ScrobbleFailure.rejected,
        'Last.fm did not return a token.',
      );
    }
    return token;
  }

  /// Page where the user approves Studio for [token].
  Uri authorizeUrl(String token) => Uri.https('www.last.fm', '/api/auth/', {
    'api_key': apiKey,
    'token': token,
  });

  Future<LastFmSession> getSession(String token) async {
    final json = await _call({'method': 'auth.getSession', 'token': token});
    final session = json['session'];
    if (session is Map && session['key'] is String) {
      return LastFmSession(
        key: session['key'] as String,
        user: '${session['name'] ?? ''}',
      );
    }
    throw const ScrobbleException(
      ScrobbleFailure.auth,
      'Last.fm did not return a session.',
    );
  }

  Future<void> updateNowPlaying(String sessionKey, ScrobbleTrack track) async {
    await _call({
      'method': 'track.updateNowPlaying',
      'sk': sessionKey,
      'artist': track.artist,
      'track': track.title,
      if (track.album != null) 'album': track.album!,
      if (track.duration > Duration.zero)
        'duration': '${track.duration.inSeconds}',
    });
  }

  Future<void> scrobble(String sessionKey, List<ScrobbleTrack> batch) async {
    final params = <String, String>{
      'method': 'track.scrobble',
      'sk': sessionKey,
    };
    for (var i = 0; i < batch.length; i++) {
      final track = batch[i];
      params['artist[$i]'] = track.artist;
      params['track[$i]'] = track.title;
      params['timestamp[$i]'] = '${track.startedAtSeconds}';
      if (track.album != null) params['album[$i]'] = track.album!;
      if (track.duration > Duration.zero) {
        params['duration[$i]'] = '${track.duration.inSeconds}';
      }
    }
    await _call(params);
  }

  Future<Map<String, dynamic>> _call(Map<String, String> params) async {
    final body = {...params, 'api_key': apiKey};
    body['api_sig'] = sign(body, secret);
    body['format'] = 'json';
    final http.Response response;
    try {
      response = await _http.post(_endpoint, body: body).timeout(_timeout);
    } on SocketException catch (error) {
      throw ScrobbleException(ScrobbleFailure.retry, '$error');
    } on http.ClientException catch (error) {
      throw ScrobbleException(ScrobbleFailure.retry, '$error');
    } on TimeoutException {
      throw const ScrobbleException(ScrobbleFailure.retry, 'Timed out.');
    }
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      json = null;
    }
    if (json is Map<String, dynamic> && json['error'] != null) {
      final code = json['error'] is int ? json['error'] as int : -1;
      final message = '${json['message'] ?? 'Last.fm error $code'}';
      throw ScrobbleException(
        _authErrors.contains(code)
            ? ScrobbleFailure.auth
            : _retryErrors.contains(code)
            ? ScrobbleFailure.retry
            : ScrobbleFailure.rejected,
        message,
      );
    }
    if (response.statusCode >= 500 || response.statusCode == 429) {
      throw ScrobbleException(
        ScrobbleFailure.retry,
        'Last.fm returned HTTP ${response.statusCode}.',
      );
    }
    if (response.statusCode != 200 || json is! Map<String, dynamic>) {
      throw ScrobbleException(
        ScrobbleFailure.rejected,
        'Last.fm returned HTTP ${response.statusCode}.',
      );
    }
    return json;
  }
}

class LastFmScrobbleService implements ScrobbleService {
  LastFmScrobbleService({required this.client, required this.sessionKey});

  final LastFmClient client;
  final String sessionKey;

  @override
  String get id => 'lastfm';

  @override
  int get maxBatch => 50;

  @override
  Future<void> nowPlaying(ScrobbleTrack track) =>
      client.updateNowPlaying(sessionKey, track);

  @override
  Future<void> submit(List<ScrobbleTrack> batch) =>
      client.scrobble(sessionKey, batch);
}
