import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/genre_color.dart';

void main() {
  test('a genre keeps its colour whatever its spelling', () {
    expect(genreHue('Synthwave'), genreHue('  synthwave '));
    expect(
      genreColors('Synthwave', Brightness.dark).accent,
      genreColors('synthwave', Brightness.dark).accent,
    );
  });

  test('familiar genres share a family hue', () {
    expect(genreHue('Death Metal'), genreHue('Metal'));
    expect(genreHue('Deep House'), genreHue('Techno'));
    // "Soundtrack" must not be caught by a shorter word inside it.
    expect(genreHue('Film Score'), genreHue('Soundtrack'));
    expect(genreHue('Rock'), isNot(genreHue('Jazz')));
  });

  test('unknown genres spread across the wheel', () {
    final hues = {
      for (final g in ['Zydeco', 'Vaporwave', 'Gqom', 'Fado', 'Enka'])
        genreHue(g),
    };
    expect(hues.length, greaterThan(3));
    expect(hues.every((h) => h >= 0 && h < 360), isTrue);
  });

  test('light and dark themes get readable variants', () {
    final dark = genreColors('Jazz', Brightness.dark);
    final light = genreColors('Jazz', Brightness.light);
    expect(dark.surface.computeLuminance(), lessThan(0.1));
    expect(light.surface.computeLuminance(), greaterThan(0.8));
    expect(
      dark.accent.computeLuminance(),
      greaterThan(dark.surface.computeLuminance()),
    );
  });
}
