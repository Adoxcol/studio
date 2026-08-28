import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/media_kit_bootstrap.dart';

void main() {
  test('discards a leftover NativeReferenceHolder file for this pid', () {
    final file = mediaKitReferenceHolderFile();
    file.writeAsStringSync('0');
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    discardStaleMediaKitReferenceHolder();
    expect(file.existsSync(), isFalse);
  });

  test('discard is a no-op when the file is missing', () {
    final file = mediaKitReferenceHolderFile();
    if (file.existsSync()) file.deleteSync();
    discardStaleMediaKitReferenceHolder();
    expect(file.existsSync(), isFalse);
  });
}
