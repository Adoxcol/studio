import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

typedef ArtistPictureGet = Future<Uint8List> Function(Uri uri, int maxBytes);

/// Public v1 key 123, not a user's secret. Free name search returns only one
/// result, so it cannot establish an unambiguous identity. Use verified MBIDs.
class AudioDbArtistPictureSource {
  AudioDbArtistPictureSource({
    this.requestSpacing = const Duration(milliseconds: 2100),
    this.log = const ArtistPictureLog(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Duration requestSpacing;
  final ArtistPictureLog log;
  final DateTime Function() _clock;
  DateTime? _lastRequest;
  ArtistServiceException? _cooldown;
  int _failures = 0;
  bool _rejected = false;

  Future<DownloadedArtistPicture?> fetch(
    ArtistImageRequest artist,
    String mbid,
    ArtistPictureGet get, {
    required bool Function() cancelled,
  }) async {
    if (!validArtistId(mbid)) throw const FormatException('Invalid artist ID');
    if (_rejected) return null;
    final cooldown = _cooldown;
    if (cooldown != null && _clock().isBefore(cooldown.retryAfter!)) {
      throw cooldown;
    }
    final previous = _lastRequest;
    if (previous != null) {
      final wait = requestSpacing - _clock().difference(previous);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    if (cancelled()) throw StateError('Lookup cancelled');
    _lastRequest = _clock();
    try {
      final bytes = await get(
        Uri.https('www.theaudiodb.com', '/api/v1/json/123/artist-mb.php', {
          'i': mbid,
        }),
        2 * 1024 * 1024,
      );
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (!json.containsKey('artists') ||
          (json['artists'] != null && json['artists'] is! List)) {
        throw const FormatException('Unexpected TheAudioDB artist response');
      }
      final artists = (json['artists'] as List? ?? const [])
          .whereType<Map>()
          .toList();
      if (artists.isEmpty) {
        _resetFailures();
        log('TheAudioDB has no entry for this artist ID.', artist: artist.name);
        return null;
      }
      if (artists.length != 1 || artists.single['strMusicBrainzID'] != mbid) {
        throw const FormatException(
          'TheAudioDB returned an unexpected artist identity',
        );
      }
      final entry = artists.single;
      final id = entry['idArtist'];
      final url = entry['strArtistThumb'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (id is! String ||
          !RegExp(r'^\d+$').hasMatch(id) ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.hasPort ||
          uri.hasQuery ||
          uri.userInfo.isNotEmpty ||
          !const {
            'www.theaudiodb.com',
            'theaudiodb.com',
            'r2.theaudiodb.com',
          }.contains(uri.host) ||
          !uri.path.startsWith('/images/media/artist/thumb/')) {
        _resetFailures();
        log(
          'No usable TheAudioDB portrait; trying Wikimedia.',
          artist: artist.name,
        );
        return null;
      }
      log('Downloading TheAudioDB artist portrait.', artist: artist.name);
      final image = await get(uri, 8 * 1024 * 1024);
      _resetFailures();
      return DownloadedArtistPicture(
        image,
        PictureCredit(
          source: 'TheAudioDB',
          author: 'Image supplied by TheAudioDB',
          license:
              'Copyright belongs to the respective rights holders. No image license supplied by the API.',
          pageUrl: 'https://www.theaudiodb.com/artist/$id',
          licenseUrl: '',
        ),
      );
    } on http.ClientException catch (error) {
      if (cancelled()) rethrow;
      if (error is ArtistServiceException && error.status == 404) {
        _resetFailures();
        return null;
      }
      if (error is ArtistServiceException &&
          (error.status == 401 || error.status == 403)) {
        _rejected = true;
        log(
          'TheAudioDB rejected the public key; skipping this source for this session.',
        );
        return null;
      }
      _failures = (_failures + 1).clamp(1, 5);
      var retry = _clock().add(
        Duration(seconds: (60 * (1 << (_failures - 1))).clamp(60, 900)),
      );
      if (error is ArtistServiceException &&
          error.retryAfter != null &&
          error.retryAfter!.isAfter(retry)) {
        retry = error.retryAfter!;
      }
      final deferred = ArtistServiceException(
        'www.theaudiodb.com',
        error is ArtistServiceException ? error.status : 503,
        retryAfter: retry,
      );
      _cooldown = deferred;
      log(
        'TheAudioDB unavailable; pausing its requests until ${retry.toLocal().toIso8601String()}.',
        artist: artist.name,
      );
      throw deferred;
    }
  }

  void _resetFailures() {
    _failures = 0;
    _cooldown = null;
  }
}
