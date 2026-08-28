import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scanner.dart';
import 'package:studio/library/tag_reader.dart';

class _TaggedReader extends TagReader {
  @override
  ParsedTags read(File file) {
    return ParsedTags(
      title: p.basenameWithoutExtension(file.path),
      artwork: Uint8List.fromList(const [0xFF, 0xD8, 0xFF]),
      artworkMime: 'image/jpeg',
    );
  }
}

void main() {
  test('scanner indexes supported files in a folder', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);

    final dir = Directory.systemTemp.createTempSync('studio-scan');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File(p.join(dir.path, 'Nocturne.flac')).writeAsStringSync('not audio');
    File(p.join(dir.path, 'notes.txt')).writeAsStringSync('ignore me');

    final count = await FolderScanner(db: db).scan(dir.path);
    expect(count, 1);

    final tracks = await db.allTracks();
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Nocturne');
    expect(tracks.single.artworkPath, equals(null));
  });

  test('scanner writes cover art through the artwork store', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final artDir = Directory.systemTemp.createTempSync('studio-scan-art');
    addTearDown(() {
      if (artDir.existsSync()) artDir.deleteSync(recursive: true);
    });
    final music = Directory.systemTemp.createTempSync('studio-scan-music');
    addTearDown(() {
      if (music.existsSync()) music.deleteSync(recursive: true);
    });
    File(p.join(music.path, 'Blue.flac')).writeAsStringSync('not audio');

    await FolderScanner(
      db: db,
      tagReader: _TaggedReader(),
      artwork: ArtworkStore(artDir),
    ).scan(music.path);

    final track = (await db.allTracks()).single;
    expect(track.artworkPath, isA<String>());
    expect(File(track.artworkPath!).existsSync(), isTrue);
  });
}
