import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_store.dart';
import 'package:studio/theming/oklch.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/theming/studio_theme.dart';

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

  test('labelFor uses a name on a seed and degrees in between', () {
    expect(AccentSeed.labelFor(200), 'TEAL');
    expect(AccentSeed.labelFor(173), '173°');
    expect(AccentSeed.wrap(-10), 350);
    expect(AccentSeed.terracotta.matches(30), isTrue);
    expect(AccentSeed.terracotta.matches(200), isFalse);
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
    expect(loaded.trackLayout, TrackLayout.cards);
    expect(loaded.showTrackArtwork, isTrue);
    expect(loaded.themeMode, AppThemeMode.light);
  });

  test('file store round-trips track layout and hidden artwork', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-appearance').path}/appearance.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FileAppearanceStore(file).save(
      const AppearanceState(
        trackLayout: TrackLayout.list,
        showTrackArtwork: false,
      ),
    );
    final loaded = FileAppearanceStore(file).load();
    expect(loaded.trackLayout, TrackLayout.list);
    expect(loaded.showTrackArtwork, isFalse);
    expect(loaded.fetchMissingArtwork, isTrue);
  });

  test('file store round-trips disabled cover download', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-appearance').path}/appearance.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FileAppearanceStore(
      file,
    ).save(const AppearanceState(fetchMissingArtwork: false));
    expect(FileAppearanceStore(file).load().fetchMissingArtwork, isFalse);
  });

  test('file store round-trips Full Player section visibility', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-appearance').path}/appearance.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FileAppearanceStore(file).save(
      const AppearanceState(
        fullPlayerAlbumArt: false,
        fullPlayerArtistArt: false,
        fullPlayerLyrics: true,
        fullPlayerFileInfo: false,
        fullPlayerAudioSettings: true,
      ),
    );
    final loaded = FileAppearanceStore(file).load();
    expect(loaded.fullPlayerAlbumArt, isFalse);
    expect(loaded.fullPlayerArtistArt, isFalse);
    expect(loaded.fullPlayerLyrics, isTrue);
    expect(loaded.fullPlayerFileInfo, isFalse);
    expect(loaded.fullPlayerAudioSettings, isTrue);
  });

  test('omitted track layout and artwork default', () {
    const state = AppearanceState(mode: AccentMode.custom);
    expect(state.trackLayout, TrackLayout.cards);
    expect(state.showTrackArtwork, isTrue);
    expect(state.copyWith().trackLayout, TrackLayout.cards);
  });

  test('file store round-trips dark theme mode', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-appearance').path}/appearance.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    final store = FileAppearanceStore(file);
    store.save(
      const AppearanceState(
        mode: AccentMode.custom,
        customHue: 200,
        themeMode: AppThemeMode.dark,
      ),
    );
    final loaded = FileAppearanceStore(file).load();
    expect(loaded.themeMode, AppThemeMode.dark);
    expect(loaded.mode, AccentMode.custom);
    expect(loaded.customHue, 200);
  });

  test('missing themeMode in appearance.json defaults to light', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-appearance').path}/appearance.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    file.writeAsStringSync('{"mode":"custom","customHue":200}');
    final loaded = FileAppearanceStore(file).load();
    expect(loaded.themeMode, AppThemeMode.light);
    expect(loaded.mode, AccentMode.custom);
  });

  test('forBrightness picks the dark surfaces', () {
    expect(
      StudioPalette.forBrightness(Brightness.dark).bg,
      StudioPalette.dark().bg,
    );
    expect(
      StudioPalette.forBrightness(Brightness.light).bg,
      StudioPalette.light().bg,
    );
  });

  test('theme mode names map to Flutter ThemeMode', () {
    expect(AppThemeMode.fromName(null), AppThemeMode.light);
    expect(AppThemeMode.fromName('dark'), AppThemeMode.dark);
    expect(AppThemeMode.fromName('system'), AppThemeMode.system);
    expect(AppThemeMode.fromName('nope'), AppThemeMode.light);
    expect(StudioTheme.materialMode(AppThemeMode.dark), ThemeMode.dark);
    expect(StudioTheme.materialMode(AppThemeMode.system), ThemeMode.system);
    expect(
      StudioTheme.windowBackground(AppThemeMode.dark),
      StudioPalette.dark().bg,
    );
    expect(
      StudioTheme.windowBackground(AppThemeMode.light),
      StudioPalette.light().bg,
    );
  });
}
