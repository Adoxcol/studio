import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_store.dart';
import 'package:studio/theming/oklch.dart';
import 'package:studio/theming/studio_palette.dart';

void main() {
  test('light terracotta accent matches the design token', () {
    expect(StudioPalette.light().accent, const Color(0xFFAC5346));
    expect(StudioPalette.light().bg, const Color(0xFFF9F4EE));
  });

  test('dark accent is the brighter terracotta', () {
    expect(StudioPalette.dark().accent, const Color(0xFFE17363));
  });

  test('named seed hues match the mockup hex values', () {
    expect(
      StudioPalette.light(hue: AccentSeed.ochre.hue).accent,
      const Color(0xFF916A00),
    );
    expect(
      StudioPalette.light(hue: AccentSeed.sage.hue).accent,
      const Color(0xFF48823B),
    );
    expect(
      StudioPalette.light(hue: AccentSeed.teal.hue).accent,
      const Color(0xFF00858D),
    );
    expect(
      StudioPalette.light(hue: AccentSeed.indigo.hue).accent,
      const Color(0xFF576CB7),
    );
  });

  test('changing hue keeps surfaces and only shifts accent', () {
    final terracotta = StudioPalette.light();
    final teal = StudioPalette.light(hue: AccentSeed.teal.hue);
    expect(teal.bg, terracotta.bg);
    expect(teal.ink, terracotta.ink);
    expect(teal.accent, isNot(terracotta.accent));
  });

  test('oklch hue round-trips through sRGB', () {
    final color = Oklch.color(l: 0.55, c: 0.12, h: 30);
    final back = Oklch.fromColor(color);
    expect(back.h, closeTo(30, 1.5));
  });

  test('nearest seed wraps the hue wheel', () {
    expect(AccentSeed.nearest(28), AccentSeed.terracotta);
    expect(AccentSeed.nearest(200), AccentSeed.teal);
    expect(AccentSeed.nearest(350), AccentSeed.terracotta);
  });

  test('file store round-trips custom teal', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-appearance').path}/appearance.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    final store = FileAppearanceStore(file);
    store.save(const AppearanceState(mode: AccentMode.custom, customHue: 200));
    final loaded = FileAppearanceStore(file).load();
    expect(loaded.mode, AccentMode.custom);
    expect(loaded.customHue, 200);
  });
}
