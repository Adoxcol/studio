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

    await FolderScanner(db: db).scan(music.path);
    expect((await db.allTracks()).single.artworkPath, track.artworkPath);
  });

  test('rescanKnown indexes new files in stored folders', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('studio-rescan');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File(p.join(dir.path, 'One.flac')).writeAsStringSync('not audio');
    final scanner = FolderScanner(db: db);
    await scanner.scan(dir.path);

    File(p.join(dir.path, 'Two.flac')).writeAsStringSync('not audio');
    await scanner.rescanKnown();

    final titles = (await db.allTracks()).map((t) => t.title).toSet();
    expect(titles, {'One', 'Two'});
  });

  test('rescan drops tracks whose files were deleted', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('studio-prune');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final gone = File(p.join(dir.path, 'Gone.flac'))
      ..writeAsStringSync('not audio');
    File(p.join(dir.path, 'Stay.flac')).writeAsStringSync('not audio');
    final scanner = FolderScanner(db: db);
    await scanner.scan(dir.path);
    expect(await db.allTracks(), hasLength(2));

    gone.deleteSync();
    await scanner.rescanKnown();

    final tracks = await db.allTracks();
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Stay');
    expect(await db.allFolders(), hasLength(1));
  });

  test(
    'rescan of a missing folder clears its tracks but keeps the folder',
    () async {
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final dir = Directory.systemTemp.createTempSync('studio-missing');
      File(p.join(dir.path, 'Temp.flac')).writeAsStringSync('not audio');
      final scanner = FolderScanner(db: db);
      await scanner.scan(dir.path);
      dir.deleteSync(recursive: true);

      await scanner.rescanKnown();

      expect(await db.allTracks(), isEmpty);
      expect(await db.allFolders(), hasLength(1));
    },
  );
}
