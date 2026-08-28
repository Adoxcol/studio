import 'dart:io';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:studio/theming/oklch.dart';

/// Hue of the most chromatic color in [path], or null if none is usable.
Future<double?> hueFromArtwork(String path) async {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    final generator = await PaletteGenerator.fromImageProvider(
      FileImage(file),
      maximumColorCount: 12,
      timeout: const Duration(seconds: 2),
    );
    final candidates = <Color>[
      if (generator.vibrantColor != null) generator.vibrantColor!.color,
      if (generator.lightVibrantColor != null)
        generator.lightVibrantColor!.color,
      if (generator.darkVibrantColor != null) generator.darkVibrantColor!.color,
      if (generator.dominantColor != null) generator.dominantColor!.color,
      ...generator.colors,
    ];
    Oklch? best;
    for (final color in candidates) {
      final oklch = Oklch.fromColor(color);
      if (oklch.c < 0.04) continue;
      if (best == null || oklch.c > best.c) best = oklch;
    }
    return best?.h;
  } on Object {
    return null;
  }
}
