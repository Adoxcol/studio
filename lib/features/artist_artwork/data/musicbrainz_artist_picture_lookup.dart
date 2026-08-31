import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/audio_db_artist_picture_source.dart';
import 'package:studio/features/artist_artwork/data/artist_identity_store.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

/// Verified MusicBrainz identity -> fanart.tv -> TheAudioDB -> Wikidata / Commons.
/// Deliberately does not scrape image search or guess by popularity.
class MusicBrainzArtistPictureLookup implements ArtistPictureLookup {
  MusicBrainzArtistPictureLookup({
    http.Client? client,
    bool enableAudioDb = false,
    AudioDbArtistPictureSource? audioDb,
    ArtistIdentityStore? identities,
    FanartSettings fanart = const FanartSettings(),
    this.requestSpacing = const Duration(milliseconds: 1100),
    this.requestTimeout = const Duration(seconds: 15),
    this.transferTimeout = const Duration(seconds: 90),
    this.log = const ArtistPictureLog(),
  }) : _client = client ?? http.Client(),
       _identities = identities ?? ArtistIdentityStore(),
       _fanart = fanart,
       _audioDb =
           audioDb ??
           (enableAudioDb ? AudioDbArtistPictureSource(log: log) : null);
  final AudioDbArtistPictureSource? _audioDb;
  final ArtistIdentityStore _identities;
  FanartSettings _fanart;
  bool _fanartRejected = false;

  void configureFanart(FanartSettings settings) {
    cancel();
    _fanart = settings;
    _fanartRejected = false;
    log(
      settings.enabled
          ? 'fanart.tv enabled; credentials omitted from logs.'
          : 'fanart.tv disabled; using Wikimedia.',
    );
  }

  final http.Client _client;
  final Duration requestSpacing;
  final Duration requestTimeout;
  final Duration transferTimeout;
  final ArtistPictureLog log;
  DateTime? _lastRequest;
  final _aborts = <Completer<void>>{};
  int _generation = 0;
  bool _closed = false;
  static const _userAgent = 'Studio/0.1 (https://github.com/Adoxcol/studio)';

  @override
  Future<DownloadedArtistPicture?> fetch(ArtistImageRequest artist) async {
    DownloadedArtistPicture? missing(String reason) {
      log(reason, artist: artist.name);
      return null;
    }

    if (!artist.searchable) {
      return missing('Skipped: missing or generic artist name.');
    }
    final generation = _generation;
    Future<Map<String, dynamic>> json(Uri uri) =>
        _json(uri, generation, artist.name);
    var id = await _identities.load(artist);
    if (id == null) {
      id = await _resolveId(artist, json);
      if (id == null) return null;
      // Save before the next request: a provider outage must not lose a match.
      await _identities.save(artist, id);
      log('MusicBrainz match: $id.', artist: artist.name);
    } else {
      log('Cached MusicBrainz match: $id.', artist: artist.name);
    }
    if (_closed || generation != _generation) {
      throw StateError('Lookup cancelled');
    }
    if (_fanart.enabled && !_fanartRejected) {
      final picture = await _fetchFanart(artist, id, generation);
      if (picture != null) return picture;
    }
    Object? sourceError;
    if (_audioDb != null) {
      try {
        final picture = await _audioDb.fetch(
          artist,
          id,
          (uri, maxBytes) =>
              _get(uri, generation, maxBytes, artist: artist.name),
          cancelled: () => _closed || generation != _generation,
        );
        if (picture != null) return picture;
      } on Object catch (error) {
        if (_closed || generation != _generation) rethrow;
        sourceError = error;
        log(
          'TheAudioDB lookup unavailable; trying Wikimedia.',
          artist: artist.name,
        );
      }
    }
    final picture = await _fetchWikimedia(artist, id, generation);
    // An unavailable source is not a definitive no-image result.
    if (picture == null && sourceError != null) throw sourceError;
    return picture;
  }

  Future<Map<String, dynamic>> _json(
    Uri uri,
    int generation,
    String artist,
  ) async =>
      jsonDecode(
            utf8.decode(
              await _get(uri, generation, 2 * 1024 * 1024, artist: artist),
            ),
          )
          as Map<String, dynamic>;

  Future<DownloadedArtistPicture?> _fetchWikimedia(
    ArtistImageRequest artist,
    String id,
    int generation,
  ) async {
    DownloadedArtistPicture? missing(String reason) {
      log(reason, artist: artist.name);
      return null;
    }

    Future<Map<String, dynamic>> json(Uri uri) =>
        _json(uri, generation, artist.name);
    final identity = await json(
      Uri.https('musicbrainz.org', '/ws/2/artist/$id', {
        'fmt': 'json',
        'inc': 'url-rels',
      }),
    );
    String? entityId;
    for (final relation in _maps(identity['relations'])) {
      if (relation['type'] != 'wikidata') continue;
      final resource = (relation['url'] as Map?)?['resource'];
      final uri = resource is String ? Uri.tryParse(resource) : null;
      if (uri == null ||
          !const {'www.wikidata.org', 'wikidata.org'}.contains(uri.host)) {
        continue;
      }
      final last = uri.pathSegments.lastOrNull;
      if (last != null && RegExp(r'^Q[0-9]+$').hasMatch(last)) {
        entityId = last;
        break;
      }
    }
    if (entityId == null) {
      return missing('No linked Wikidata entry for this artist.');
    }
    log('Following Wikidata entry $entityId.', artist: artist.name);
    final entity = await json(
      Uri.https('www.wikidata.org', '/w/api.php', {
        'action': 'wbgetentities',
        'ids': entityId,
        'props': 'claims',
        'format': 'json',
      }),
    );
    if (entity['error'] != null) {
      throw const FormatException('Wikidata request failed.');
    }
    final claims = (entity['entities'] as Map?)?[entityId] as Map?;
    final images =
        _maps(
          (claims?['claims'] as Map?)?['P18'],
        ).where((e) => e['rank'] != 'deprecated').toList()..sort(
          (a, b) => (b['rank'] == 'preferred' ? 1 : 0).compareTo(
            a['rank'] == 'preferred' ? 1 : 0,
          ),
        );
    if (images.isEmpty) return missing('Wikidata has no artist photo (P18).');
    final filename =
        ((images.first['mainsnak'] as Map?)?['datavalue'] as Map?)?['value'];
    if (filename is! String || filename.contains('|')) {
      return missing('Skipped: Wikidata photo filename is invalid.');
    }
    final commons = await json(
      Uri.https('commons.wikimedia.org', '/w/api.php', {
        'action': 'query',
        'format': 'json',
        'prop': 'imageinfo',
        'titles': 'File:$filename',
        'iiprop': 'url|extmetadata',
        'iiurlwidth': '640',
        'iiextmetadatafilter': 'Artist|LicenseShortName|LicenseUrl|UsageTerms',
      }),
    );
    if (commons['error'] != null) {
      throw const FormatException('Commons request failed.');
    }
    final pages = (commons['query'] as Map?)?['pages'] as Map?;
    for (final page in pages?.values ?? const []) {
      for (final info in _maps((page as Map)['imageinfo'])) {
        final uri = Uri.tryParse(
          info['thumburl'] as String? ?? info['url'] as String? ?? '',
        );
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host != 'upload.wikimedia.org') {
          log(
            'Skipped image: download URL is not an approved HTTPS Wikimedia host.',
            artist: artist.name,
          );
          continue;
        }
        final meta = info['extmetadata'];
        String field(String name) {
          final entry = meta is Map ? meta[name] : null;
          final value = entry is Map ? entry['value'] : null;
          return value is String ? _plainText(value) : '';
        }

        final author = field('Artist');
        final licenseName = field('LicenseShortName');
        final license = licenseName.isNotEmpty
            ? licenseName
            : field('UsageTerms');
        final description = info['descriptionurl'];
        final pageUrl = description is String ? description.trim() : '';
        final missingCredits = [
          if (author.isEmpty) 'author',
          if (license.isEmpty) 'license',
          if (pageUrl.isEmpty) 'source page',
        ];
        if (missingCredits.isNotEmpty) {
          log(
            'Commons metadata incomplete (${missingCredits.join(', ')}); downloading image and retaining available credits.',
            artist: artist.name,
          );
        }
        // Incomplete optional credits do not reject a verified artist photo.
        // Unknown licensing is recorded as unknown, never as permission to reuse.
        final savedLicense = license.isEmpty
            ? 'License information not supplied'
            : license;
        log(
          'Downloading Commons photo "$filename" ($savedLicense).',
          artist: artist.name,
        );
        return DownloadedArtistPicture(
          await _get(uri, generation, 8 * 1024 * 1024, artist: artist.name),
          PictureCredit(
            author: author.isEmpty ? 'Author not supplied' : author,
            license: savedLicense,
            pageUrl: pageUrl.isNotEmpty
                ? pageUrl
                : Uri.https(
                    'commons.wikimedia.org',
                    '/wiki/File:$filename',
                  ).toString(),
            licenseUrl: field('LicenseUrl'),
          ),
        );
      }
    }
    return missing('No usable Wikimedia Commons image.');
  }

  Future<String?> _resolveId(
    ArtistImageRequest artist,
    Future<Map<String, dynamic>> Function(Uri) json,
  ) async {
    String? missing(String reason) {
      log(reason, artist: artist.name);
      return null;
    }

    final search = await json(
      Uri.https('musicbrainz.org', '/ws/2/artist/', {
        'query': 'artist:${_quote(artist.name)}',
        'fmt': 'json',
        'limit': '100',
      }),
    );
    // Truncated results cannot prove an unambiguous identity.
    if ((search['count'] as num? ?? 0) > 100) {
      return missing(
        'Skipped: MusicBrainz results are truncated; identity is uncertain.',
      );
    }
    final candidates = _maps(search['artists'])
        .where(
          (entry) =>
              artistKey(entry['name'] as String? ?? '') == artist.key ||
              _maps(entry['aliases']).any(
                (alias) =>
                    artistKey(alias['name'] as String? ?? '') == artist.key,
              ),
        )
        .toList();
    String? id;
    if (candidates.length == 1) {
      id = candidates.single['id'] as String?;
    } else if (candidates.length > 1) {
      log(
        '${candidates.length} exact-name matches; checking local album titles.',
        artist: artist.name,
      );
      // An exact local album title can distinguish artists sharing a name.
      final ids = candidates.map((e) => e['id']).toSet();
      for (final album in artist.albums.take(3)) {
        final releases = await json(
          Uri.https('musicbrainz.org', '/ws/2/release-group/', {
            'query':
                'releasegroup:${_quote(album)} AND artist:${_quote(artist.name)}',
            'fmt': 'json',
            'limit': '100',
          }),
        );
        if ((releases['count'] as num? ?? 0) > 100) continue;
        final matching = <String>{};
        for (final release in _maps(releases['release-groups'])) {
          if (artistKey(release['title'] as String? ?? '') !=
              artistKey(album)) {
            continue;
          }
          for (final credit in _maps(release['artist-credit'])) {
            final candidate = (credit['artist'] as Map?)?['id'];
            if (candidate is String && ids.contains(candidate)) {
              matching.add(candidate);
            }
          }
        }
        if (matching.length == 1) {
          id = matching.single;
          log('Identity confirmed by album "$album".', artist: artist.name);
          break;
        }
      }
    }
    if (id == null || !validArtistId(id)) {
      return missing(
        candidates.isEmpty
            ? 'No exact artist match in MusicBrainz.'
            : 'Skipped: artist identity is ambiguous or invalid.',
      );
    }
    return id;
  }

  Future<DownloadedArtistPicture?> _fetchFanart(
    ArtistImageRequest artist,
    String id,
    int generation,
  ) async {
    Map<String, dynamic> data;
    try {
      data =
          jsonDecode(
                utf8.decode(
                  await _get(
                    Uri.https('webservice.fanart.tv', '/v3.2/music/$id'),
                    generation,
                    2 * 1024 * 1024,
                    artist: artist.name,
                    headers: _fanart.headers,
                  ),
                ),
              )
              as Map<String, dynamic>;
    } on ArtistServiceException catch (error) {
      if (_closed || generation != _generation) rethrow;
      if (error.status == 401 || error.status == 403) {
        _fanartRejected = true;
        log(
          'fanart.tv rejected the keys (HTTP ${error.status}); check Settings. Using Wikimedia until keys change.',
        );
        return null;
      }
      if (error.status != 404) rethrow;
      log('No fanart.tv entry; trying Wikimedia.', artist: artist.name);
      return null;
    }
    if (data['mbid_id'] != id) {
      throw const FormatException('fanart.tv returned a different artist ID');
    }
    final thumbnails = _maps(data['artistthumb']).toList()
      ..sort((a, b) {
        int likes(Map value) => int.tryParse('${value['likes']}') ?? 0;
        final order = likes(b).compareTo(likes(a));
        return order != 0 ? order : '${a['id']}'.compareTo('${b['id']}');
      });
    for (final thumbnail in thumbnails) {
      final value = thumbnail['url'];
      final uri = value is String ? Uri.tryParse(value) : null;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'assets.fanart.tv' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort ||
          uri.hasQuery) {
        continue;
      }
      log('Downloading fanart.tv artist portrait.', artist: artist.name);
      try {
        return DownloadedArtistPicture(
          await _get(uri, generation, 8 * 1024 * 1024, artist: artist.name),
          PictureCredit(
            source: 'fanart.tv',
            author: 'Image supplied by fanart.tv',
            license:
                'Copyright belongs to the respective rights holders. No image license supplied by the API.',
            pageUrl: 'https://fanart.tv/artist/$id/',
            licenseUrl: 'https://fanart.tv/terms-and-conditions/',
          ),
        );
      } on ArtistServiceException catch (error) {
        if (error.status != 404) rethrow;
        // A deleted thumbnail should not hide another available photo.
      }
    }
    log('No usable fanart.tv portrait; trying Wikimedia.', artist: artist.name);
    return null;
  }

  Future<Uint8List> _get(
    Uri uri,
    int generation,
    int maxBytes, {
    required String artist,
    Map<String, String> headers = const {},
  }) async {
    // One worker uses this lookup. Space ALL metadata/image requests to also
    // avoid bursts against Wikimedia, including after a fast failure.
    final previous = _lastRequest;
    if (previous != null) {
      final remaining = requestSpacing - DateTime.now().difference(previous);
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
    if (_closed || generation != _generation) {
      throw StateError('Lookup cancelled');
    }
    _lastRequest = DateTime.now();
    final elapsed = Stopwatch()..start();
    log('GET ${uri.host}${uri.path}', artist: artist);
    final abort = Completer<void>();
    _aborts.add(abort);
    var received = 0;
    Timer? idleTimer;
    void abortRequest(String reason) {
      log('$reason on ${uri.host} after $received bytes.', artist: artist);
      if (!abort.isCompleted) abort.complete();
    }

    void resetIdleTimeout() {
      idleTimer?.cancel();
      idleTimer = Timer(
        requestTimeout,
        () => abortRequest(
          'No network progress for ${requestTimeout.inSeconds}s',
        ),
      );
    }

    // A large portrait can take more than 15 seconds on a slow connection.
    // Abort stalled requests, not progressing transfers; retain an absolute
    // deadline so a trickling endpoint cannot occupy the worker indefinitely.
    resetIdleTimeout();
    final deadline = Timer(
      transferTimeout,
      () => abortRequest('Transfer deadline reached'),
    );
    try {
      final request =
          http.AbortableRequest('GET', uri, abortTrigger: abort.future)
            ..followRedirects = false
            ..headers['User-Agent'] = _userAgent
            ..headers.addAll(headers);
      final response = await _client.send(request);
      resetIdleTimeout();
      if (response.statusCode != 200) {
        log('HTTP ${response.statusCode} from ${uri.host}.', artist: artist);
        final retryAfter = artistRetryAfter(
          response.headers['retry-after'],
          DateTime.now(),
        );
        final zone = response.headers['x-ratelimit-zone'];
        if (zone != null) log('Rate-limit zone: $zone.', artist: artist);
        await response.stream.listen((_) {}).cancel();
        throw ArtistServiceException(
          uri.host,
          response.statusCode,
          retryAfter: retryAfter,
        );
      }
      if ((response.contentLength ?? 0) > maxBytes) {
        throw const FormatException('Image response too large');
      }
      final bytes = BytesBuilder(copy: false);
      log(
        'HTTP 200 headers from ${uri.host} in ${elapsed.elapsedMilliseconds}ms; receiving body.',
        artist: artist,
      );
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Image response too large');
        }
        bytes.add(chunk);
        received = bytes.length;
        if (chunk.isNotEmpty) resetIdleTimeout();
      }
      log(
        'HTTP 200 from ${uri.host}: ${bytes.length} bytes in ${elapsed.elapsedMilliseconds}ms.',
        artist: artist,
      );
      return bytes.takeBytes();
    } finally {
      idleTimer?.cancel();
      deadline.cancel();
      _aborts.remove(abort);
      if (!abort.isCompleted) abort.complete();
    }
  }

  @override
  void cancel() {
    _generation++;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
  }

  @override
  void close() {
    _closed = true;
    cancel();
    _client.close();
  }
}

Iterable<Map> _maps(Object? value) =>
    value is List ? value.whereType<Map>() : const [];
String _quote(String value) =>
    '"${value.replaceAllMapped(RegExp(r'([+\-!(){}\[\]^"~*?:\\/]|&&|\|\|)'), (m) => '\\${m[0]}')}"';
String _plainText(String value) => value
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ')
    .trim();
