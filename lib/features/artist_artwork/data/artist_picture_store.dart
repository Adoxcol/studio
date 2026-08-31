import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

abstract interface class ArtistPictureStore {
  Future<ArtistPicture> load(String key);
  Future<void> save(String key, ArtistPicture picture);
  Future<String> saveImage(Uint8List bytes);
}

class MemoryArtistPictureStore implements ArtistPictureStore {
  final pictures = <String, ArtistPicture>{};
  @override
  Future<ArtistPicture> load(String key) async =>
      pictures[key] ?? const ArtistPicture();
  @override
  Future<void> save(String key, ArtistPicture picture) async {
    pictures[key] = picture;
  }

  @override
  Future<String> saveImage(Uint8List bytes) async =>
      '${sha256.convert(bytes)}.png';
}

/// Immutable image files plus a small atomic manifest per normalized artist.
/// No original music files, embedded covers or user-selected files are changed.
class FileArtistPictureStore implements ArtistPictureStore {
  FileArtistPictureStore(this.directory, {int Function()? sourceRevision})
    : _sourceRevision = sourceRevision ?? (() => 0);
  final Directory directory;
  final int Function() _sourceRevision;
  static const _cacheVersion = 4;
  int _writeSequence = 0;
  File _manifest(String key) =>
      File(p.join(directory.path, '${sha256.convert(utf8.encode(key))}.json'));

  @override
  Future<ArtistPicture> load(String key) async {
    final file = _manifest(key);
    if (!await file.exists()) return const ArtistPicture();
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      Future<String?> imagePath(Object? name) async {
        // Manifests may reference only this cache, never arbitrary local files.
        if (name is! String || !RegExp(r'^[a-f0-9]{64}\.png$').hasMatch(name)) {
          return null;
        }
        final image = File(p.join(directory.path, name));
        return await image.exists() && await image.length() > 0
            ? image.path
            : null;
      }

      final custom = await imagePath(json['custom']);
      final remote = await imagePath(json['remote']);
      // Retry old misses now that incomplete Commons credits are accepted.
      // Keep version-3 transient-failure deadlines to respect service backoff.
      final keepRetry =
          json['sourceRevision'] == _sourceRevision() &&
          (json['version'] == _cacheVersion ||
              (json['version'] == 3 && json['failed'] == true));
      return ArtistPicture(
        customPath: custom,
        remotePath: remote,
        hidden: json['hidden'] == true,
        credit: json['credit'] == null
            ? null
            : PictureCredit.fromJson(json['credit'] as Map<String, dynamic>),
        retryAfter: keepRetry
            ? DateTime.tryParse(json['retryAfter'] as String? ?? '')
            : null,
        lookupState: json['failed'] == true
            ? PictureLookupState.failed
            : PictureLookupState.missing,
      );
    } on FormatException {
      return const ArtistPicture();
    } on TypeError {
      return const ArtistPicture();
    }
  }

  @override
  Future<void> save(String key, ArtistPicture picture) async {
    await directory.create(recursive: true);
    final file = _manifest(key);
    final part = File('${file.path}.part');
    await part.writeAsString(
      jsonEncode({
        'version': _cacheVersion,
        'sourceRevision': _sourceRevision(),
        'custom': picture.customPath == null
            ? null
            : p.basename(picture.customPath!),
        'remote': picture.remotePath == null
            ? null
            : p.basename(picture.remotePath!),
        'credit': picture.credit?.toJson(),
        'hidden': picture.hidden,
        'retryAfter': picture.retryAfter?.toUtc().toIso8601String(),
        'failed': picture.lookupState == PictureLookupState.failed,
      }),
      flush: true,
    );
    await part.rename(file.path);
  }

  @override
  Future<String> saveImage(Uint8List bytes) async {
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, '${sha256.convert(bytes)}.png'));
    if (await file.exists()) return file.path;
    // Unique staging files also protect concurrent manual imports.
    final part = await File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}-${_writeSequence++}.part',
    ).create();
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(file.path);
    return file.path;
  }
}
