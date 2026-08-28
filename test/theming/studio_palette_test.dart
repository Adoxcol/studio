import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/studio_palette.dart';

void main() {
  test('light terracotta accent matches the design token', () {
    expect(StudioPalette.light().accent, const Color(0xFFAC5346));
    expect(StudioPalette.light().bg, const Color(0xFFF9F4EE));
  });

  test('dark accent is the brighter terracotta', () {
    expect(StudioPalette.dark().accent, const Color(0xFFE17363));
  });
}
