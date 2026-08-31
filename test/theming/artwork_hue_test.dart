import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/artwork_hue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns null if file does not exist', () async {
    final result = await hueFromArtwork('non_existent_file.png');
    expect(result, isNull);
  });

  test('returns hue for a valid chromatic image', () async {
    final file = File('test_red_image.png');
    // 1x1 red pixel png
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    await file.writeAsBytes(bytes);

    try {
      final result = await hueFromArtwork(file.path);
      expect(result, isNotNull);
      expect(result, closeTo(29.23, 0.1));
    } finally {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });

  test(
    'returns null for an achromatic image (no color with c >= 0.04)',
    () async {
      final file = File('test_grey_image.png');
      // 1x1 grey pixel png
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mM8c+bMfwAHjAMH8t1T+AAAAABJRU5ErkJggg==',
      );
      await file.writeAsBytes(bytes);

      try {
        final result = await hueFromArtwork(file.path);
        expect(result, isNull);
      } finally {
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    },
  );

  test('returns null if file is not an image (causes exception)', () async {
    final file = File('test_invalid_image.txt');
    await file.writeAsString('not an image');

    try {
      final result = await hueFromArtwork(file.path);
      expect(result, isNull);
    } finally {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });
}
