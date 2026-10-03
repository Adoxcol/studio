import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/media_kit_bootstrap.dart';

void main() {
  test('discards a leftover NativeReferenceHolder file for this pid', () {
    final dir = Directory.systemTemp.createTempSync('studio-media-kit-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = mediaKitReferenceHolderFile(tempDir: dir.path);
    file.writeAsStringSync('0');
    discardStaleMediaKitReferenceHolder(tempDir: dir.path);
    expect(file.existsSync(), isFalse);
  });

  test('discard is a no-op when the file is missing', () {
    final dir = Directory.systemTemp.createTempSync('studio-media-kit-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = mediaKitReferenceHolderFile(tempDir: dir.path);
    if (file.existsSync()) file.deleteSync();
    discardStaleMediaKitReferenceHolder(tempDir: dir.path);
    expect(file.existsSync(), isFalse);
  });
}
