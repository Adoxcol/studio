import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/cover_art_lookup.dart';
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

class _PartialArtReader extends TagReader {
  @override
  ParsedTags read(File file, {bool getImage = false}) {
    final name = p.basenameWithoutExtension(file.path);
    return ParsedTags(
      title: name,
      artist: 'Aria Solvang',
      album: 'Afterglow',
      artwork: name == 'One' && getImage
          ? Uint8List.fromList(const [0xFF, 0xD8, 0xFF])
          : null,
      artworkMime: 'image/jpeg',
    );
  }
}

class _AlbumReader extends TagReader {
  @override
  ParsedTags read(File file, {bool getImage = false}) {
    return ParsedTags(
      title: p.basenameWithoutExtension(file.path),
      artist: 'Aria Solvang',
      album: 'Afterglow',
    );
  }
}

class _FakeCovers implements CoverArtLookup {
  var calls = 0;

  @override
  Future<Uint8List?> fetch({
    required String artist,
    required String album,
  }) async {
    calls++;
    expect(artist, 'Aria Solvang');
    expect(album, 'Afterglow');
    return Uint8List.fromList(const [0xFF, 0xD8, 0xFF]);
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

  test('rescan of a missing folder preserves its tracks and folder', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final dir = Directory.systemTemp.createTempSync('studio-missing');
    File(p.join(dir.path, 'Temp.flac')).writeAsStringSync('not audio');
    final scanner = FolderScanner(db: db);
    await scanner.scan(dir.path);
    dir.deleteSync(recursive: true);

    final result = await scanner.rescanKnown();

    expect(result.unavailableFolders, 1);
    expect(await db.allTracks(), hasLength(1));
    expect(await db.allFolders(), hasLength(1));
  });

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

  test('scanner copies album art onto tracks that lack a picture', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final artDir = Directory.systemTemp.createTempSync('studio-share-art');
    addTearDown(() {
      if (artDir.existsSync()) artDir.deleteSync(recursive: true);
    });
    final music = Directory.systemTemp.createTempSync('studio-share-music');
    addTearDown(() {
      if (music.existsSync()) music.deleteSync(recursive: true);
    });
    File(p.join(music.path, 'One.flac')).writeAsStringSync('not audio');
    File(p.join(music.path, 'Two.flac')).writeAsStringSync('not audio');

    await FolderScanner(
      db: db,
      tagReader: _PartialArtReader(),
      artwork: ArtworkStore(artDir),
    ).scan(music.path);

    final tracks = await db.allTracks();
    expect(tracks, hasLength(2));
    expect(tracks.every((t) => t.artworkPath != null), isTrue);
    expect(tracks[0].artworkPath, tracks[1].artworkPath);
  });

  test('scanner uses cover.jpg next to the audio files', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final artDir = Directory.systemTemp.createTempSync('studio-folder-art');
    addTearDown(() {
      if (artDir.existsSync()) artDir.deleteSync(recursive: true);
    });
    final music = Directory.systemTemp.createTempSync('studio-folder-music');
    addTearDown(() {
      if (music.existsSync()) music.deleteSync(recursive: true);
    });
    File(p.join(music.path, 'Blue.flac')).writeAsStringSync('not audio');
    File(
      p.join(music.path, 'cover.jpg'),
    ).writeAsBytesSync(Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]));

    await FolderScanner(
      db: db,
      tagReader: _CountingReader(),
      artwork: ArtworkStore(artDir),
    ).scan(music.path);

    final track = (await db.allTracks()).single;
    expect(track.artworkPath, isA<String>());
    expect(File(track.artworkPath!).existsSync(), isTrue);
  });

  test('scanner downloads one cover per album when tags have none', () async {
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    final artDir = Directory.systemTemp.createTempSync('studio-itunes-art');
    addTearDown(() {
      if (artDir.existsSync()) artDir.deleteSync(recursive: true);
    });
    final music = Directory.systemTemp.createTempSync('studio-itunes-music');
    addTearDown(() {
      if (music.existsSync()) music.deleteSync(recursive: true);
    });
    File(p.join(music.path, 'One.flac')).writeAsStringSync('not audio');
    File(p.join(music.path, 'Two.flac')).writeAsStringSync('not audio');
    final covers = _FakeCovers();

    await FolderScanner(
      db: db,
      tagReader: _AlbumReader(),
      artwork: ArtworkStore(artDir),
      covers: covers,
    ).scan(music.path);

    expect(covers.calls, 1);
    final tracks = await db.allTracks();
    expect(tracks.every((t) => t.artworkPath != null), isTrue);
    expect(tracks[0].artworkPath, tracks[1].artworkPath);
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
