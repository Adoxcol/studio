import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:studio/theming/studio_palette.dart';

class SkinFormatException implements Exception {
  const SkinFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Palette tokens a skin may override. The accent is excluded: it always
/// follows album art or the user's custom hue.
const skinTokens = [
  'bg',
  'ink',
  'inkMuted',
  'inkMutedAlt',
  'inkDim',
  'inkBright',
  'hairline',
  'hairlineSoft',
  'hairlineStrong',
  'hairlineAlt',
  'artSwatch',
];

/// Colour overrides for one brightness. Missing tokens keep Studio's.
class SkinPalette {
  const SkinPalette([this.colors = const {}]);

  final Map<String, Color> colors;

  StudioPalette applyTo(StudioPalette base) => base.copyWith(
    bg: colors['bg'],
    ink: colors['ink'],
    inkMuted: colors['inkMuted'],
    inkMutedAlt: colors['inkMutedAlt'],
    inkDim: colors['inkDim'],
    inkBright: colors['inkBright'],
    hairline: colors['hairline'],
    hairlineSoft: colors['hairlineSoft'],
    hairlineStrong: colors['hairlineStrong'],
    hairlineAlt: colors['hairlineAlt'],
    artSwatch: colors['artSwatch'],
  );

  static SkinPalette capture(StudioPalette palette) => SkinPalette({
    'bg': palette.bg,
    'ink': palette.ink,
    'inkMuted': palette.inkMuted,
    'inkMutedAlt': palette.inkMutedAlt,
    'inkDim': palette.inkDim,
    'inkBright': palette.inkBright,
    'hairline': palette.hairline,
    'hairlineSoft': palette.hairlineSoft,
    'hairlineStrong': palette.hairlineStrong,
    'hairlineAlt': palette.hairlineAlt,
    'artSwatch': palette.artSwatch,
  });

  Map<String, String> toJson() => {
    for (final token in skinTokens)
      if (colors[token] case final color?) token: hexOf(color),
  };
}

/// A shareable `.studioskin` file: a name plus light and dark overrides.
class Skin {
  const Skin({
    required this.name,
    this.author,
    this.light = const SkinPalette(),
    this.dark = const SkinPalette(),
    this.accentHue,
  });

  static const format = 'studio-skin';
  static const version = 1;
  static const fileExtension = 'studioskin';

  /// Imports are rejected above this size.
  static const maxBytes = 64 * 1024;

  /// WCAG AA for body text, and 3:1 for secondary text.
  static const minInkContrast = 4.5;
  static const minMutedContrast = 3.0;

  final String name;
  final String? author;
  final SkinPalette light;
  final SkinPalette dark;

  /// Suggested custom accent hue, applied when the skin is chosen.
  final double? accentHue;

  /// Stable id derived from the content, so re-importing is idempotent.
  String get id {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final hash = sha1.convert(utf8.encode(encode())).toString().substring(0, 8);
    return '${slug.isEmpty ? 'skin' : slug}-$hash';
  }

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': format,
    'version': version,
    'name': name,
    if (author != null) 'author': author,
    if (accentHue != null) 'accentHue': accentHue,
    'light': light.toJson(),
    'dark': dark.toJson(),
  });

  /// Parses and validates a skin file, including text contrast in both
  /// modes against Studio's built-in palettes.
  static Skin parse(String source) {
    if (source.length > maxBytes) {
      throw const SkinFormatException('Skin files must be smaller than 64 KB.');
    }
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const SkinFormatException('This is not a valid skin file.');
    }
    if (json is! Map || json['format'] != format) {
      throw const SkinFormatException('This is not a Studio skin file.');
    }
    if (json['version'] != version) {
      throw const SkinFormatException(
        'This skin was made for a different version of Studio.',
      );
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty || name.trim().length > 60) {
      throw const SkinFormatException(
        'A skin needs a name of up to 60 characters.',
      );
    }
    final author = json['author'];
    final hue = json['accentHue'];
    final skin = Skin(
      name: name.trim(),
      author: author is String && author.trim().isNotEmpty
          ? author.trim().substring(0, author.trim().length.clamp(0, 60))
          : null,
      accentHue: hue is num && hue.isFinite ? hue.toDouble() % 360 : null,
      light: _palette(json['light'], 'light'),
      dark: _palette(json['dark'], 'dark'),
    );
    skin._checkContrast(StudioPalette.light(), 'light');
    skin._checkContrast(StudioPalette.dark(), 'dark');
    return skin;
  }

  static SkinPalette _palette(Object? json, String mode) {
    if (json == null) return const SkinPalette();
    if (json is! Map) {
      throw SkinFormatException('The $mode palette must be an object.');
    }
    final colors = <String, Color>{};
    for (final token in skinTokens) {
      final value = json[token];
      if (value == null) continue;
      final color = value is String ? parseHex(value) : null;
      if (color == null) {
        throw SkinFormatException(
          '$mode.$token must be a colour like "#1A2B3C".',
        );
      }
      colors[token] = color;
    }
    return SkinPalette(colors);
  }

  void _checkContrast(StudioPalette base, String mode) {
    final palette = (mode == 'light' ? light : dark).applyTo(base);
    final ink = contrastRatio(palette.ink, palette.bg);
    final muted = contrastRatio(palette.inkMuted, palette.bg);
    if (ink < minInkContrast || muted < minMutedContrast) {
      throw SkinFormatException(
        'Text in the $mode palette is too hard to read '
        '(contrast ${ink.toStringAsFixed(1)}:1 for text, '
        '${muted.toStringAsFixed(1)}:1 for secondary text; '
        'needs $minInkContrast:1 and $minMutedContrast:1).',
      );
    }
  }
}

/// `#RRGGBB` only: skins are opaque surfaces and text.
Color? parseHex(String value) {
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value.trim());
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

String hexOf(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// WCAG 2 contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
