import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/tag_reader.dart';

void main() {
  test('falls back to the file name when tags cannot be read', () {
    final dir = Directory.systemTemp.createTempSync('studio-tags');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final file = File(p.join(dir.path, 'Ghosts.mp3'))
      ..writeAsStringSync('not audio');
    final tags = const TagReader().read(file);
    expect(tags.title, 'Ghosts');
  });
}
