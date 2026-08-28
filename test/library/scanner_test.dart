import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/database.dart';
import 'package:studio/library/scanner.dart';

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

    final tracks = await db.watchTracks().first;
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Nocturne');
  });
}
