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
  ParsedTags read(File file, {bool getImage = false}) {
    return ParsedTags(
      title: p.basenameWithoutExtension(file.path),
      artwork: Uint8List.fromList(const [0xFF, 0xD8, 0xFF]),
      artworkMime: 'image/jpeg',
    );
  }
}

class _CountingReader extends TagReader {
  var reads = 0;

  @override
  ParsedTags read(File file, {bool getImage = false}) {
    reads++;
    return ParsedTags(title: p.basenameWithoutExtension(file.path));
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

    final result = await FolderScanner(db: db).scan(dir.path);
    expect(result.seen, 1);
    expect(result.written, 1);

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

  test('second scan skips unchanged files', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('studio-skip');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File(p.join(dir.path, 'Same.flac')).writeAsStringSync('not audio');
    final reader = _CountingReader();
    final scanner = FolderScanner(db: db, tagReader: reader);
    await scanner.scan(dir.path);
    expect(reader.reads, 1);
    final again = await scanner.scan(dir.path);
    expect(again.skipped, 1);
    expect(again.written, 0);
    expect(reader.reads, 1);
  });

  test('cancel stops a scan without pruning unseen files', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('studio-cancel');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    for (var i = 0; i < 8; i++) {
      File(p.join(dir.path, '$i.flac')).writeAsStringSync('not audio');
    }
    var processed = 0;
    final result = await FolderScanner(db: db).scan(
      dir.path,
      isCancelled: () => processed >= 3,
      onProgress: (progress) {
        processed = progress.processed;
      },
    );
    expect(result.cancelled, isTrue);
    expect(await db.allTracks(), isNotEmpty);
    expect((await db.allTracks()).length, lessThan(8));
  });

  test('deleteFolder removes the folder and its tracks', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('studio-remove');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File(p.join(dir.path, 'A.flac')).writeAsStringSync('not audio');
    await FolderScanner(db: db).scan(dir.path);
    final folder = (await db.allFolders()).single;
    await db.deleteFolder(folder.id);
    expect(await db.allTracks(), isEmpty);
    expect(await db.allFolders(), isEmpty);
  });
}
