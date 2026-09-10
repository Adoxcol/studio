import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:studio/discord/discord_ids.dart';

/// Turns a local cover path into a Discord `large_image` value.
abstract class DiscordArtworkResolver {
  /// Cache hit only. Does not hit the network.
  String? cachedUrl(String? path) => null;

  /// Upload if needed. Returns the HTTPS URL when done.
  Future<String?> urlFor(String? path);
}

typedef DiscordImagePoster =
    Future<String> Function(List<int> bytes, String filename);

/// Uploads covers to Freeimage and remembers its Discord-compatible `iili.io`
/// URL so the same file is not sent twice.
class FreeImageArtworkUploader implements DiscordArtworkResolver {
  FreeImageArtworkUploader({
    required this.cacheFile,
    DiscordImagePoster? poster,
    this.maxBytes = 8 * 1024 * 1024,
    Duration? failCooldown,
  }) : _poster = poster,
       _failCooldown = failCooldown;

  final File cacheFile;
  final DiscordImagePoster? _poster;
  final int maxBytes;
  final Duration? _failCooldown;

  final _mem = <String, String>{};
  Map<String, String>? _disk;
  final _inflight = <String, Future<String?>>{};
  final _failedAt = <String, DateTime>{};

  @override
  String? cachedUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final key = _cacheKey(file);
    final cached = _mem[key] ?? _loadDisk()[key];
    if (cached != null) _mem[key] = cached;
    return cached;
  }

  @override
  Future<String?> urlFor(String? path) async {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final key = _cacheKey(file);
    final cached = _mem[key] ?? _loadDisk()[key];
    if (cached != null) {
      _mem[key] = cached;
      return cached;
    }
    if (_cooling(key)) return null;
    debugPrint('Discord artwork: uploading $path');
    return _inflight.putIfAbsent(key, () => _upload(file, key));
  }

  Future<String?> _upload(File file, String key) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > maxBytes) {
        debugPrint(
          'Discord artwork: skipped ${file.path} (${bytes.length} bytes, '
          'limit $maxBytes)',
        );
        return null;
      }
      final poster = _poster ?? _post;
      final url = await poster(bytes, _filename(bytes));
      if (!_isUsableCachedUrl(url) || url.length > kDiscordAssetLimit) {
        debugPrint('Discord artwork: rejected upload response "$url"');
        return null;
      }
      _mem[key] = url;
      _loadDisk()[key] = url;
      _saveDisk();
      _failedAt.remove(key);
      debugPrint('Discord artwork: uploaded $url');
      return url;
    } on Object catch (error) {
      _failedAt[key] = DateTime.now();
      debugPrint('Discord artwork upload failed: $error');
      return null;
    } finally {
      _inflight.remove(key);
    }
  }

  /// A fresh connection per upload: covers are uploaded rarely enough that
  /// pooling isn't worth it, and a long-lived client risks reusing a
  /// keep-alive socket the host has already dropped, which surfaces as a
  /// sporadic, hard-to-reproduce upload failure.
  Future<String> _post(List<int> bytes, String filename) {
    return postToFreeImage(bytes, filename);
  }

  bool _cooling(String key) {
    final at = _failedAt[key];
    if (at == null) return false;
    return DateTime.now().difference(at) <
        (_failCooldown ?? const Duration(minutes: 2));
  }

  Map<String, String> _loadDisk() {
    final existing = _disk;
    if (existing != null) return existing;
    final loaded = <String, String>{};
    try {
      if (cacheFile.existsSync()) {
        final json = jsonDecode(cacheFile.readAsStringSync());
        if (json is Map) {
          for (final entry in json.entries) {
            final url = entry.value;
            if (entry.key is String &&
                url is String &&
                _isUsableCachedUrl(url)) {
              loaded[entry.key as String] = url;
            }
          }
        }
      }
    } on Object {
      // Corrupt cache: start empty.
    }
    _disk = loaded;
    return loaded;
  }

  void _saveDisk() {
    final disk = _disk;
    if (disk == null) return;
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(jsonEncode(disk));
  }

  static String _cacheKey(File file) {
    final stat = file.statSync();
    return '${file.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
  }

  static String _filename(List<int> bytes) {
    return imageFilenameFor(bytes);
  }

  static bool _isUsableCachedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    // Catbox responds with valid image bytes but Discord renders those URLs as
    // unknown assets. Do not let a persisted Catbox entry prevent migration to
    // the working provider after an app update.
    return uri.host != 'files.catbox.moe' && uri.host != 'catbox.moe';
  }
}

/// POST a local image using Freeimage's documented multipart API. The returned
/// `image.url` is the direct `iili.io` URL, not a viewer page.
Future<String> postToFreeImage(
  List<int> bytes,
  String filename, {
  Uri? endpoint,
  String apiKey = kFreeImagePublicApiKey,
}) async {
  final request =
      http.MultipartRequest('POST', endpoint ?? Uri.parse(kFreeImageUploadUrl))
        ..fields['key'] = apiKey
        ..fields['action'] = 'upload'
        ..fields['format'] = 'json'
        ..files.add(
          http.MultipartFile.fromBytes(
            'source',
            bytes,
            filename: filename,
            contentType: MediaType.parse(imageContentType(bytes)),
          ),
        );
  // Bounds the whole round trip, not just headers: a connection that stalls
  // mid-body would otherwise hang this upload (and the `_inflight` entry
  // caching it) forever.
  final response = await http.Response.fromStream(
    await request.send(),
  ).timeout(const Duration(seconds: 20));
  final url = parseFreeImageUploadUrl(response.body);
  if (response.statusCode < 200 || response.statusCode >= 300 || url == null) {
    throw StateError('freeimage.host ${response.statusCode}: ${response.body}');
  }
  return url;
}

String imageContentType(List<int> bytes) {
  if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String imageFilenameFor(List<int> bytes) {
  switch (imageContentType(bytes)) {
    case 'image/png':
      return 'artwork.png';
    case 'image/gif':
      return 'artwork.gif';
    case 'image/webp':
      return 'artwork.webp';
    default:
      return 'artwork.jpg';
  }
}

/// Reads the direct image URL from a Freeimage API v1 JSON response.
String? parseFreeImageUploadUrl(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final image = decoded['image'];
    if (image is! Map) return null;
    final value = image['url'];
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri.toString();
  } on FormatException {
    return null;
  }
}

String discordLargeImage(String? url) {
  if (url == null || url.isEmpty) return kDiscordLargeImageKey;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      url.length > kDiscordAssetLimit) {
    return kDiscordLargeImageKey;
  }
  // Discord expects the source URL here and converts it into an `mp:` media
  // proxy asset itself. An `mp:` identifier observed through the gateway is an
  // output owned by Discord, not a value applications can synthesize.
  return url;
}
