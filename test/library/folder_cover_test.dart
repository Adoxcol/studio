import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/folder_cover.dart';

void main() {
  test('finds cover.jpg next to the files', () async {
    final dir = Directory.systemTemp.createTempSync('studio-folder-cover');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File(p.join(dir.path, 'song.flac')).writeAsStringSync('x');
    File(p.join(dir.path, 'cover.jpg')).writeAsBytesSync(const [1, 2, 3]);
    final coverFile = await FolderCover.find(dir.path);
    expect(coverFile?.path, p.join(dir.path, 'cover.jpg'));
  });

  test('ignores empty files and unrelated images', () async {
    final dir = Directory.systemTemp.createTempSync('studio-folder-empty');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    File(p.join(dir.path, 'cover.jpg')).writeAsBytesSync(const []);
    File(p.join(dir.path, 'photo.png')).writeAsBytesSync(const [1]);
    expect(await FolderCover.find(dir.path), equals(null));
  });
}
