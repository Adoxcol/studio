import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/studio_palette.dart';

abstract final class StudioTheme {
  static ThemeData light({double hue = AccentSeed.defaultHue}) =>
      _build(StudioPalette.light(hue: hue), Brightness.light);

  static ThemeData dark({double hue = AccentSeed.defaultHue}) =>
      _build(StudioPalette.dark(hue: hue), Brightness.dark);

  static ThemeData _build(StudioPalette palette, Brightness brightness) {
    final workSans = GoogleFonts.workSansTextTheme().apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );
    final spectral = GoogleFonts.spectral(
      color: palette.ink,
      fontWeight: FontWeight.w500,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      dividerColor: palette.hairline,
      textTheme: workSans.copyWith(
        displayLarge: spectral.copyWith(fontSize: 44, height: 1.05),
        displayMedium: spectral.copyWith(fontSize: 32, height: 1.1),
        displaySmall: spectral.copyWith(fontSize: 24, height: 1.15),
        headlineMedium: spectral.copyWith(fontSize: 20, height: 1.2),
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.accent,
        onPrimary: palette.bg,
        secondary: palette.inkMuted,
        onSecondary: palette.bg,
        error: palette.accentPressed,
        onError: palette.bg,
        surface: palette.bg,
        onSurface: palette.ink,
      ),
      iconTheme: IconThemeData(color: palette.inkMutedAlt, size: 22),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        textStyle: GoogleFonts.workSans(fontSize: 12, color: palette.bg),
        decoration: BoxDecoration(color: palette.ink),
      ),
      extensions: [palette],
    );
  }
}
