/// 8-band graphic EQ matching the Playback & Sound artboard.
abstract final class Equalizer {
  static const bandsHz = [60, 150, 400, 1000, 2500, 6000, 12000, 16000];
  static const labels = ['60', '150', '400', '1k', '2.5k', '6k', '12k', '16k'];
  static const minGain = -12.0;
  static const maxGain = 12.0;

  static const List<double> flat = [0, 0, 0, 0, 0, 0, 0, 0];
  static const List<double> warm = [3, 2, 1, 0, 0, -1, -2, -2];
  static const List<double> bright = [-2, -1, 0, 0, 1, 2, 3, 3];

  static List<double> gainsFor(EqualizerPreset preset, List<double> custom) {
    return switch (preset) {
      EqualizerPreset.flat => List<double>.from(flat),
      EqualizerPreset.warm => List<double>.from(warm),
      EqualizerPreset.bright => List<double>.from(bright),
      EqualizerPreset.custom => List<double>.from(custom),
    };
  }

  /// mpv `af` value. Always empty: media_kit's libmpv has no `firequalizer`
  /// or `aresample`, so a lavfi graph mutes playback and flushes the decoder
  /// (the playhead jumps) on every EQ change.
  static String afFilter(List<double> gains) {
    if (gains.isEmpty) return '';
    return '';
  }
}

enum EqualizerPreset {
  flat('Flat'),
  warm('Warm'),
  bright('Bright'),
  custom('Custom');

  const EqualizerPreset(this.label);
  final String label;

  static EqualizerPreset fromName(String? name) {
    for (final preset in values) {
      if (preset.name == name) return preset;
    }
    return EqualizerPreset.flat;
  }
}
