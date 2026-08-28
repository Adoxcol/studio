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
      final delta = hueDelta(seed.hue, hue);
      if (delta < bestDelta) {
        bestDelta = delta;
        best = seed;
      }
    }
    return best;
  }

  static double hueDelta(double a, double b) {
    final raw = (a - b).abs() % 360;
    return raw > 180 ? 360 - raw : raw;
  }

  static double wrap(double hue) {
    final n = hue % 360;
    return n < 0 ? n + 360 : n;
  }

  /// Named seed when [hue] sits on one; otherwise the degree.
  static String labelFor(double hue) {
    final nearestSeed = nearest(hue);
    if (hueDelta(nearestSeed.hue, hue) <= 8) {
      return nearestSeed.label.toUpperCase();
    }
    return '${wrap(hue).round()}°';
  }

  bool matches(double hue, {double tolerance = 8}) {
    return hueDelta(this.hue, hue) <= tolerance;
  }
}

enum AccentMode { auto, custom }

enum AppThemeMode {
  light,
  dark,
  system;

  String get label => switch (this) {
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
    AppThemeMode.system => 'System',
  };

  static AppThemeMode fromName(String? name) {
    return switch (name) {
      'dark' => AppThemeMode.dark,
      'system' => AppThemeMode.system,
      _ => AppThemeMode.light,
    };
  }
}

enum TrackLayout {
  cards,
  list;

  String get label => switch (this) {
    TrackLayout.cards => 'Cards',
    TrackLayout.list => 'List',
  };

  static TrackLayout fromName(String? name) {
    return name == 'list' ? TrackLayout.list : TrackLayout.cards;
  }
}

class AppearanceState {
  const AppearanceState({
    this.mode = AccentMode.auto,
    this.customHue = AccentSeed.defaultHue,
    TrackLayout? trackLayout,
    bool? showTrackArtwork,
    bool? fetchMissingArtwork,
    AppThemeMode? themeMode,
  }) : _trackLayout = trackLayout,
       _showTrackArtwork = showTrackArtwork,
       _fetchMissingArtwork = fetchMissingArtwork,
       _themeMode = themeMode;

  final AccentMode mode;
  final double customHue;
  final TrackLayout? _trackLayout;
  final bool? _showTrackArtwork;
  final bool? _fetchMissingArtwork;
  final AppThemeMode? _themeMode;

  TrackLayout get trackLayout => _trackLayout ?? TrackLayout.cards;
  bool get showTrackArtwork => _showTrackArtwork ?? true;
  bool get fetchMissingArtwork => _fetchMissingArtwork ?? true;
  AppThemeMode get themeMode => _themeMode ?? AppThemeMode.light;

  static const defaults = AppearanceState();

  AppearanceState copyWith({
    AccentMode? mode,
    double? customHue,
    TrackLayout? trackLayout,
    bool? showTrackArtwork,
    bool? fetchMissingArtwork,
    AppThemeMode? themeMode,
  }) {
    return AppearanceState(
      mode: mode ?? this.mode,
      customHue: customHue ?? this.customHue,
      trackLayout: trackLayout ?? this.trackLayout,
      showTrackArtwork: showTrackArtwork ?? this.showTrackArtwork,
      fetchMissingArtwork: fetchMissingArtwork ?? this.fetchMissingArtwork,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
