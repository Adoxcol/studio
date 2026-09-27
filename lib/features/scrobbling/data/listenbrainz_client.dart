import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:studio/core/app_info.dart';
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/domain/scrobble_track.dart';

/// ListenBrainz submission API with a user token.
class ListenBrainzClient {
  ListenBrainzClient({
    required this.token,
    http.Client? httpClient,
    Uri? baseUrl,
  }) : _http = httpClient ?? http.Client(),
       _base = baseUrl ?? Uri.parse('https://api.listenbrainz.org');

  final String token;
  final http.Client _http;
  final Uri _base;

  static const _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
    'Authorization': 'Token $token',
    'Content-Type': 'application/json',
  };

  /// Returns the user name the token belongs to.
  Future<String> validateToken() async {
    final response = await _send(
      () => _http.get(_base.resolve('/1/validate-token'), headers: _headers),
    );
    final json = _decode(response);
    if (json is Map && json['valid'] == true && json['user_name'] is String) {
      return json['user_name'] as String;
    }
    throw const ScrobbleException(
      ScrobbleFailure.auth,
      'ListenBrainz did not accept this token.',
    );
  }

  Future<void> playingNow(ScrobbleTrack track) =>
      _submit('playing_now', [track], timestamps: false);

  Future<void> submit(List<ScrobbleTrack> batch) =>
      _submit(batch.length == 1 ? 'single' : 'import', batch);

  Future<void> _submit(
    String type,
    List<ScrobbleTrack> tracks, {
    bool timestamps = true,
  }) async {
    final body = jsonEncode({
      'listen_type': type,
      'payload': [
        for (final track in tracks)
          {
            if (timestamps) 'listened_at': track.startedAtSeconds,
            'track_metadata': {
              'artist_name': track.artist,
              'track_name': track.title,
              if (track.album != null) 'release_name': track.album,
              'additional_info': {
                if (track.duration > Duration.zero)
                  'duration_ms': track.duration.inMilliseconds,
                'media_player': kAppName,
                'submission_client': kAppName,
                'submission_client_version': kAppVersion,
              },
            },
          },
      ],
    });
    final response = await _send(
      () => _http.post(
        _base.resolve('/1/submit-listens'),
        headers: _headers,
        body: body,
      ),
    );
    _decode(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on SocketException catch (error) {
      throw ScrobbleException(ScrobbleFailure.retry, '$error');
    } on http.ClientException catch (error) {
      throw ScrobbleException(ScrobbleFailure.retry, '$error');
    } on TimeoutException {
      throw const ScrobbleException(ScrobbleFailure.retry, 'Timed out.');
    }
  }

  Object? _decode(http.Response response) {
    final code = response.statusCode;
    if (code == 401) {
      throw const ScrobbleException(
        ScrobbleFailure.auth,
        'ListenBrainz rejected the token.',
      );
    }
    if (code == 429 || code >= 500) {
      throw ScrobbleException(
        ScrobbleFailure.retry,
        'ListenBrainz returned HTTP $code.',
      );
    }
    if (code != 200) {
      throw ScrobbleException(
        ScrobbleFailure.rejected,
        'ListenBrainz returned HTTP $code: ${response.body}',
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return null;
    }
  }
}

class ListenBrainzScrobbleService implements ScrobbleService {
  ListenBrainzScrobbleService(this.client);

  final ListenBrainzClient client;

  @override
  String get id => 'listenbrainz';

  @override
  int get maxBatch => 100;

  @override
  Future<void> nowPlaying(ScrobbleTrack track) => client.playingNow(track);

  @override
  Future<void> submit(List<ScrobbleTrack> batch) => client.submit(batch);
}
