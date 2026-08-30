import 'package:flutter/material.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/oklch.dart';

/// Editorial Mono color tokens. OKLCH comments are the design source of truth.
@immutable
class StudioPalette extends ThemeExtension<StudioPalette> {
  const StudioPalette({
    required this.bg,
    required this.ink,
    required this.inkMuted,
    required this.inkMutedAlt,
    required this.inkDim,
    required this.inkBright,
    required this.hairline,
    required this.hairlineSoft,
    required this.hairlineStrong,
    required this.hairlineAlt,
    required this.artSwatch,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
  });

  /// Light theme. Surfaces stay editorial; only accent hue changes.
  factory StudioPalette.light({double hue = AccentSeed.defaultHue}) {
    return StudioPalette(
      bg: const Color(0xFFF9F4EE), // oklch(97% 0.01 80)
      ink: const Color(0xFF181611), // oklch(20% 0.01 80)
      inkMuted: const Color(0xFF696257), // oklch(50% 0.02 80)
      inkMutedAlt: const Color(0xFF787165), // oklch(55% 0.02 80)
      inkDim: const Color(0xFF696257),
      inkBright: const Color(0xFF181611),
      hairline: const Color(0xFFE1DDD7), // oklch(90% 0.01 80)
      hairlineSoft: const Color(0xFFEBE7E1), // oklch(93% 0.01 80)
      hairlineStrong: const Color(0xFFD1CDC7), // oklch(85% 0.01 80)
      hairlineAlt: const Color(0xFFD1CDC7),
      artSwatch: const Color(0xFFE8DBD1), // oklch(90% 0.02 60)
      accent: Oklch.color(l: 0.55, c: 0.12, h: hue),
      accentHover: Oklch.color(l: 0.45, c: 0.12, h: hue),
      accentPressed: Oklch.color(l: 0.35, c: 0.12, h: hue),
    );
  }

  factory StudioPalette.forBrightness(
    Brightness brightness, {
    double hue = AccentSeed.defaultHue,
  }) {
    return brightness == Brightness.dark
        ? StudioPalette.dark(hue: hue)
        : StudioPalette.light(hue: hue);
  }

  /// Dark theme. Same hue, brighter accent (chroma 0.14, lightness 68%).
  factory StudioPalette.dark({double hue = AccentSeed.defaultHue}) {
    return StudioPalette(
      bg: const Color(0xFF13110F), // oklch(18% 0.005 80)
      ink: const Color(0xFFEAE7E4), // oklch(93% 0.005 80)
      inkMuted: const Color(0xFF898680), // oklch(62% 0.01 80)
      inkMutedAlt: const Color(0xFFA29E98),
      inkDim: const Color(0xFFA29E98), // oklch(70% 0.01 80)
      inkBright: const Color(0xFFBFBDBA), // oklch(80% 0.005 80)
      hairline: const Color(0xFF2B2823), // oklch(28% 0.01 80)
      hairlineSoft: const Color(0xFF2B2823),
      hairlineStrong: const Color(0xFF36322D), // oklch(32% 0.01 80)
      hairlineAlt: const Color(0xFF302D28), // oklch(30% 0.01 80)
      artSwatch: const Color(0xFF392A1E), // oklch(30% 0.03 60)
      accent: Oklch.color(l: 0.68, c: 0.14, h: hue),
      accentHover: Oklch.color(l: 0.58, c: 0.14, h: hue),
      accentPressed: Oklch.color(l: 0.55, c: 0.12, h: hue),
    );
  }

  final Color bg;
  final Color ink;
  final Color inkMuted;
  final Color inkMutedAlt;
  final Color inkDim;
  final Color inkBright;
  final Color hairline;
  final Color hairlineSoft;
  final Color hairlineStrong;
  final Color hairlineAlt;
  final Color artSwatch;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;

  static StudioPalette of(BuildContext context) {
    return Theme.of(context).extension<StudioPalette>()!;
  }

  @override
  StudioPalette copyWith({
    Color? bg,
    Color? ink,
    Color? inkMuted,
    Color? inkMutedAlt,
    Color? inkDim,
    Color? inkBright,
    Color? hairline,
    Color? hairlineSoft,
    Color? hairlineStrong,
    Color? hairlineAlt,
    Color? artSwatch,
    Color? accent,
    Color? accentHover,
    Color? accentPressed,
  }) {
    return StudioPalette(
      bg: bg ?? this.bg,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkMutedAlt: inkMutedAlt ?? this.inkMutedAlt,
      inkDim: inkDim ?? this.inkDim,
      inkBright: inkBright ?? this.inkBright,
      hairline: hairline ?? this.hairline,
      hairlineSoft: hairlineSoft ?? this.hairlineSoft,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      hairlineAlt: hairlineAlt ?? this.hairlineAlt,
      artSwatch: artSwatch ?? this.artSwatch,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentPressed: accentPressed ?? this.accentPressed,
    );
  }

  @override
  StudioPalette lerp(covariant StudioPalette? other, double t) {
    if (other == null) return this;
    return StudioPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkMutedAlt: Color.lerp(inkMutedAlt, other.inkMutedAlt, t)!,
      inkDim: Color.lerp(inkDim, other.inkDim, t)!,
      inkBright: Color.lerp(inkBright, other.inkBright, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineSoft: Color.lerp(hairlineSoft, other.hairlineSoft, t)!,
      hairlineStrong: Color.lerp(hairlineStrong, other.hairlineStrong, t)!,
      hairlineAlt: Color.lerp(hairlineAlt, other.hairlineAlt, t)!,
      artSwatch: Color.lerp(artSwatch, other.artSwatch, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
    );
  }
}
