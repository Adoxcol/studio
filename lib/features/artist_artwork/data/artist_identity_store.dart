import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

/// Album clues are part of the cache key: two same-name artists must not share
/// a match after the library's disambiguating metadata changes.
String artistIdentityKey(ArtistImageRequest artist) {
  final albums = artist.albums.map(artistKey).toSet().toList()..sort();
  return sha256
      .convert(utf8.encode(jsonEncode([artist.key, albums])))
      .toString();
}

bool validArtistId(String id) => RegExp(
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
).hasMatch(id);

class ArtistIdentityStore {
  ArtistIdentityStore({this.directory});
  final Directory? directory;
  final _memory = <String, String>{};

  Future<String?> load(ArtistImageRequest artist) async {
    final key = artistIdentityKey(artist);
    if (_memory.containsKey(key)) return _memory[key];
    if (directory == null) return null;
    final file = File(p.join(directory!.path, '$key.json'));
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map;
      final id = json['mbid'];
      if (id is String && validArtistId(id)) return _memory[key] = id;
    } on FormatException {
      // Malformed cache entries can be resolved again, never guessed.
    } on TypeError {
      // As above. Actual disk I/O failures propagate to the retry scheduler.
    }
    return null;
  }

  Future<void> save(ArtistImageRequest artist, String id) async {
    if (!validArtistId(id)) throw const FormatException('Invalid artist ID');
    final key = artistIdentityKey(artist);
    if (directory != null) {
      await directory!.create(recursive: true);
      final file = File(p.join(directory!.path, '$key.json'));
      final part = File('${file.path}.part');
      await part.writeAsString(jsonEncode({'mbid': id}), flush: true);
      await part.rename(file.path);
    }
    _memory[key] = id;
  }
}
