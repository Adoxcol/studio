import 'dart:convert';
import 'dart:typed_data';

import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

typedef ArtistPictureGet = Future<Uint8List> Function(Uri uri, int maxBytes);

/// Public v1 key 123, not a user's secret. Free name search returns only one
/// result, so it cannot establish an unambiguous identity. Use verified MBIDs.
class AudioDbArtistPictureSource {
  AudioDbArtistPictureSource({this.log = const ArtistPictureLog()});
  final ArtistPictureLog log;
  bool _rejected = false;

  Future<DownloadedArtistPicture?> fetch(
    ArtistImageRequest artist,
    String mbid,
    ArtistPictureGet get, {
    required bool Function() cancelled,
  }) async {
    if (!validArtistId(mbid)) throw const FormatException('Invalid artist ID');
    if (_rejected) return null;
    // Transport scheduling, rate limits and cooldowns belong to the shared
    // ArtistRequestScheduler supplied by the caller's get function.
    Uint8List bytes;
    try {
      bytes = await get(
        Uri.https('www.theaudiodb.com', '/api/v1/json/123/artist-mb.php', {
          'i': mbid,
        }),
        2 * 1024 * 1024,
      );
    } on ArtistServiceException catch (error) {
      if (cancelled()) rethrow;
      if (error.status == 404) return null;
      if (error.status == 401 || error.status == 403) {
        _rejected = true;
        log(
          'TheAudioDB rejected the public key; skipping this source for this session.',
        );
        return null;
      }
      rethrow;
    }
    if (cancelled()) throw StateError('Lookup cancelled');
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic> ||
        !json.containsKey('artists') ||
        (json['artists'] != null && json['artists'] is! List) ||
        (json['artists'] is List &&
            (json['artists'] as List).any((entry) => entry is! Map))) {
      throw const FormatException('Unexpected TheAudioDB artist response');
    }
    final artists = (json['artists'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    if (artists.isEmpty) {
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
      log(
        'No usable TheAudioDB portrait; trying Wikimedia.',
        artist: artist.name,
      );
      return null;
    }
    log('Downloading TheAudioDB artist portrait.', artist: artist.name);
    Uint8List image;
    try {
      image = await get(uri, 8 * 1024 * 1024);
    } on ArtistServiceException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
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
  }
}
