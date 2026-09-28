import 'package:flutter/painting.dart';
import 'dart:ui' show Brightness;
import 'package:studio/theming/oklch.dart';

/// Colours for one genre, tuned for the current brightness.
class GenreColors {
  const GenreColors({
    required this.accent,
    required this.surface,
    required this.border,
  });

  /// Stripe, dot and share bar.
  final Color accent;

  /// Tile background.
  final Color surface;
  final Color border;
}

/// Familiar genres get a hue that suits them; any other genre gets a stable
/// hue from its name, so it keeps its colour across launches and libraries.
double genreHue(String genre) {
  final key = genre.trim().toLowerCase();
  for (final (words, hue) in _familiar) {
    if (words.any(key.contains)) return hue;
  }
  // FNV-1a: small and stable, unlike String.hashCode across runs.
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return (hash % 360).toDouble();
}

GenreColors genreColors(String genre, Brightness brightness) {
  final hue = genreHue(genre);
  final dark = brightness == Brightness.dark;
  return GenreColors(
    accent: Oklch.color(l: dark ? 0.76 : 0.56, c: 0.13, h: hue),
    surface: Oklch.color(
      l: dark ? 0.25 : 0.955,
      c: dark ? 0.045 : 0.03,
      h: hue,
    ),
    border: Oklch.color(l: dark ? 0.34 : 0.88, c: dark ? 0.06 : 0.05, h: hue),
  );
}

// Checked in order: "neo-classical" must read as classical, not "neo" soul.
const _familiar = <(List<String>, double)>[
  (['metal', 'hardcore', 'grindcore'], 15),
  (['punk'], 350),
  (['rock', 'grunge'], 30),
  (['blues'], 250),
  (['jazz', 'swing', 'bebop'], 70),
  (['classical', 'orchestra', 'baroque', 'opera', 'piano'], 285),
  (['soundtrack', 'score', 'cinematic'], 265),
  (['hip hop', 'hip-hop', 'rap', 'trap', 'drill'], 305),
  (['r&b', 'rnb', 'soul', 'funk', 'motown'], 330),
  (['pop', 'k-pop', 'j-pop'], 345),
  (
    ['techno', 'house', 'trance', 'electro', 'edm', 'dance', 'dubstep', 'drum'],
    200,
  ),
  (['ambient', 'chill', 'lo-fi', 'lofi', 'new age'], 180),
  (['reggae', 'dub', 'ska'], 140),
  (['folk', 'country', 'bluegrass', 'americana', 'acoustic'], 95),
  (['latin', 'salsa', 'reggaeton', 'samba', 'bossa'], 50),
  (['indie', 'alternative', 'shoegaze'], 225),
  (['world', 'afro'], 115),
];
