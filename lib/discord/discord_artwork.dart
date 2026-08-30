import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

typedef DiscordImagePoster = Future<String> Function(
    List<int> bytes, String filename);

/// Uploads covers to catbox.moe (also what current `foo_discord_rich`
/// builds ship with) and remembers the HTTPS URL so the same file is not
/// sent twice.
class CatboxArtworkUploader implements DiscordArtworkResolver {
  CatboxArtworkUploader({
    required this.cacheFile,
    DiscordImagePoster? poster,
    this.maxBytes = 8 * 1024 * 1024,
    Duration? failCooldown,
  })  : _poster = poster,
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
      if (!_isHttps(url) || url.length > kDiscordAssetLimit) {
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
    return postToCatbox(bytes, filename);
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
            if (entry.key is String && url is String && _isHttps(url)) {
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

  static bool _isHttps(String url) => url.startsWith('https://');
}

/// POST to catbox.moe. No key: catbox takes anonymous uploads, and unlike
/// freeimage.host's Chevereto API — whose shared, publicly-known API key
/// (the same one `foo_discord_rich` scripts have used) started rejecting
/// every upload shape with a 400 `Can't get target upload source info`,
/// verified directly against their live endpoint with curl and Python and
/// not just our own client — catbox needs no account to keep working.
///
/// catbox's success response is the bare URL as `text/plain`, and it has
/// been observed returning a non-2xx status on an upload that still
/// succeeded, so success is read from the body shape, not the status code.
Future<String> postToCatbox(List<int> bytes, String filename) async {
  final request = http.MultipartRequest('POST', Uri.parse(kCatboxUploadUrl))
    ..fields['reqtype'] = 'fileupload'
    ..files.add(
      http.MultipartFile.fromBytes(
        'fileToUpload',
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
  final url = parseCatboxUploadUrl(response.body);
  if (url == null) {
    throw StateError('catbox.moe ${response.statusCode}: ${response.body}');
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

/// catbox's success body is just the raw URL, e.g.
/// `https://files.catbox.moe/abc123.jpg`; failures are a plain English
/// sentence, so a `https://` prefix is enough to tell them apart.
String? parseCatboxUploadUrl(String body) {
  final url = body.trim();
  if (!url.startsWith('https://')) return null;
  return url;
}

String discordLargeImage(String? url) {
  if (url == null || url.isEmpty) return kDiscordLargeImageKey;
  final asset = discordExternalAsset(url);
  if (asset == null || asset.length > kDiscordAssetLimit) {
    return kDiscordLargeImageKey;
  }
  return asset;
}

/// Classic Discord IPC rich presence — the local named-pipe protocol every
/// desktop RPC client uses, ours included — treats a plain `large_image`
/// string as a Developer Portal asset *key* lookup, not a URL. Feeding it a
/// bare `https://...` string fails that lookup silently and renders as the
/// broken/unknown-asset placeholder; wrapping it in Discord's `mp:external/`
/// media-proxy address is what actually gets an external image to render.
/// The hash only has to be stable per URL (so an unchanged cover doesn't
/// look like a new activity and rewrite the pipe every sync) — Discord's
/// own client resolves the real image server-side when broadcasting the
/// activity, it isn't verifying a signature we have no way to produce.
String? discordExternalAsset(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.authority.isEmpty) {
    return null;
  }
  final hash = base64Url.encode(sha256.convert(utf8.encode(url)).bytes);
  final rest = '${uri.authority}${uri.path}'
      '${uri.hasQuery ? '?${uri.query}' : ''}';
  return 'mp:external/${hash.replaceAll('=', '')}/https/$rest';
}
