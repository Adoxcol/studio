/// Named accent hues from the Editorial Mono mockups.
///
/// Only the hue is authored. Chroma and lightness come from
/// [StudioPalette] so auto-from-art and custom swatches share one formula.
enum AccentSeed {
  terracotta(30, 'Terracotta'),
  ochre(85, 'Ochre'),
  sage(140, 'Sage'),
  teal(200, 'Teal'),
  indigo(270, 'Indigo');

  const AccentSeed(this.hue, this.label);

  final double hue;
  final String label;

  static const defaultSeed = terracotta;
  static const defaultHue = 30.0;

  /// Closest named seed to [hue], wrapping around the color wheel.
  static AccentSeed nearest(double hue) {
    var best = terracotta;
    var bestDelta = 360.0;
    for (final seed in values) {
      final raw = (seed.hue - hue).abs() % 360;
      final delta = raw > 180 ? 360 - raw : raw;
      if (delta < bestDelta) {
        bestDelta = delta;
        best = seed;
      }
    }
    return best;
  }
}

enum AccentMode { auto, custom }

class AppearanceState {
  const AppearanceState({
    this.mode = AccentMode.auto,
    this.customHue = AccentSeed.defaultHue,
  });

  final AccentMode mode;
  final double customHue;

  static const defaults = AppearanceState();

  AppearanceState copyWith({AccentMode? mode, double? customHue}) {
    return AppearanceState(
      mode: mode ?? this.mode,
      customHue: customHue ?? this.customHue,
    );
  }
}
