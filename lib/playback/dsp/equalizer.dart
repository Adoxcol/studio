import 'dart:math' as math;

/// ISO 10-band graphic EQ (Winamp / VLC / iTunes layout).
abstract final class Equalizer {
  static const bandsHz = [
    31.5,
    63.0,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0,
  ];
  static const labels = [
    '31',
    '63',
    '125',
    '250',
    '500',
    '1k',
    '2k',
    '4k',
    '8k',
    '16k',
  ];
  static const minGain = -15.0;
  static const maxGain = 15.0;
  static const sampleRate = 48000.0;
  static const bandWidthOctaves = 1.0;
  static const _quiet = 0.05;

  static const List<double> flat = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  static const List<double> bass = [6, 5, 3, 1, 0, 0, 0, 0, 0, 0];
  static const List<double> treble = [0, 0, 0, 0, 0, 1, 3, 5, 6, 6];
  static const List<double> vocal = [-3, -2, -1, 2, 4, 4, 2, 0, -1, -2];
  static const List<double> rock = [5, 3, -2, -3, -1, 2, 4, 5, 5, 5];
  static const List<double> pop = [-1, 2, 3, 4, 3, 0, -1, -1, -1, -1];
  static const List<double> jazz = [2, 1, 0, 1, 2, 2, 1, 1, 2, 2];
  static const List<double> classical = [0, 0, 0, 0, 0, 0, -1, -2, -3, -4];
  static const List<double> dance = [6, 4, 1, 0, 0, -3, -4, -3, 0, 0];
  static const List<double> electronic = [5, 4, 1, 0, -1, 0, 2, 4, 5, 5];
  static const List<double> hipHop = [6, 5, 2, 0, -1, -1, 0, 1, 2, 2];
  static const List<double> acoustic = [3, 2, 1, 0, 1, 2, 2, 1, 1, 0];
  static const List<double> headphones = [4, 3, 1, 0, 0, 0, 1, 3, 5, 6];
  static const List<double> laptop = [6, 5, 3, 1, 0, 1, 2, 2, 3, 2];
  static const List<double> party = [5, 4, 0, 0, 0, 0, 0, 0, 4, 5];

  static double clampGain(double gain) =>
      gain.clamp(minGain, maxGain).toDouble();

  static double amplitude(double gain) => math.pow(10, gain / 40).toDouble();

  static double preampLinear(double preamp) {
    final pre = clampGain(preamp);
    if (pre.abs() < _quiet) return 1;
    return math.pow(10, pre / 20).toDouble();
  }

  static List<double> clampGains(Iterable<double> gains) {
    return [for (final gain in gains) clampGain(gain)];
  }

  static List<double> gainsFor(EqualizerPreset preset, List<double> custom) {
    return switch (preset) {
      EqualizerPreset.flat => List<double>.from(flat),
      EqualizerPreset.bass => List<double>.from(bass),
      EqualizerPreset.treble => List<double>.from(treble),
      EqualizerPreset.vocal => List<double>.from(vocal),
      EqualizerPreset.rock => List<double>.from(rock),
      EqualizerPreset.pop => List<double>.from(pop),
      EqualizerPreset.jazz => List<double>.from(jazz),
      EqualizerPreset.classical => List<double>.from(classical),
      EqualizerPreset.dance => List<double>.from(dance),
      EqualizerPreset.electronic => List<double>.from(electronic),
      EqualizerPreset.hipHop => List<double>.from(hipHop),
      EqualizerPreset.acoustic => List<double>.from(acoustic),
      EqualizerPreset.headphones => List<double>.from(headphones),
      EqualizerPreset.laptop => List<double>.from(laptop),
      EqualizerPreset.party => List<double>.from(party),
      EqualizerPreset.custom => normalizeGains(custom),
    };
  }

  /// The persistent mpv audio-filter graph.
  ///
  /// Studio's pinned Windows libmpv includes FFmpeg's realtime `equalizer`.
  /// mpv performs format/rate conversion before one fixed graph of named
  /// planar-float biquads, so lavfi never needs to negotiate a packed input.
  /// The graph is installed while stopped and never rebuilt during playback.
  static String afFilter(List<double> gains) {
    final values = normalizeGains(gains);
    final filters = <String>[
      for (var i = 0; i < bandsHz.length; i++)
        'equalizer@studio_band_$i='
            'frequency=${_frequency(bandsHz[i])}:'
            'width_type=o:width=${_number(bandWidthOctaves)}:'
            'gain=${_gain(values[i])}:precision=f32',
    ];
    return '@studio_format:format=format=floatp:srate=${sampleRate.toInt()},'
        '@studio_eq:lavfi=[${filters.join(',')}]';
  }

  /// Runtime commands for bands whose gain actually changed.
  ///
  /// Each command targets a named filter in the existing graph, so mpv does
  /// not flush the decoder, reopen the audio device, or interrupt transport.
  static List<List<String>> afCommands(
    List<double>? previous,
    List<double> gains,
  ) {
    final before = previous == null ? null : normalizeGains(previous);
    final after = normalizeGains(gains);
    return [
      for (final index in _changedBandIndices(before, after))
        afCommand(index, after[index]),
    ];
  }

  /// Highest response reached while [afCommands] changes one graph into the
  /// other. Reductions are deliberately queued before boosts to keep this
  /// transition ceiling close to the old/new steady-state ceilings.
  static double transitionPeakGainDb(
    List<double>? previous,
    List<double> gains,
  ) {
    final current = previous == null
        ? List<double>.from(flat)
        : normalizeGains(previous);
    final after = normalizeGains(gains);
    final states = <List<double>>[List<double>.from(current)];
    for (final index in _changedBandIndices(current, after)) {
      current[index] = after[index];
      states.add(List<double>.from(current));
    }
    return _peakGainDbForCurves(states);
  }

  static List<String> afCommand(int index, double gain) {
    if (index < 0 || index >= bandsHz.length) {
      throw RangeError.index(index, bandsHz, 'index');
    }
    return [
      'af-command',
      'studio_eq',
      'gain',
      _gain(clampGain(gain)),
      'equalizer@studio_band_$index',
    ];
  }

  /// Peak boost of the exact cascade used by [afFilter].
  ///
  /// The engine uses this as an automatic output ceiling. It preserves the
  /// requested curve and preamp whenever the current player volume provides
  /// enough headroom, and attenuates only the amount needed to avoid clipping.
  static double peakGainDb(List<double> gains) {
    return _peakGainDbForCurves([normalizeGains(gains)]);
  }

  static double _peakGainDbForCurves(List<List<double>> curves) {
    final cascades = [
      for (final curve in curves)
        [
          for (var band = 0; band < bandsHz.length; band++)
            if (curve[band].abs() >= _quiet)
              _Biquad.peaking(
                sampleRate: sampleRate,
                center: bandsHz[band],
                widthOctaves: bandWidthOctaves,
                gain: curve[band],
              ),
        ],
    ];
    if (cascades.every((cascade) => cascade.isEmpty)) return 0;

    var peak = 0.0;
    const points = 2048;
    final ratio = math.pow(20000 / 20, 1 / (points - 1)).toDouble();
    var frequency = 20.0;
    for (var point = 0; point < points; point++) {
      final radians = 2 * math.pi * frequency / sampleRate;
      final cosW = math.cos(radians);
      final sinW = math.sin(radians);
      final cos2W = cosW * cosW - sinW * sinW;
      final sin2W = 2 * sinW * cosW;
      for (final cascade in cascades) {
        var response = 0.0;
        for (final biquad in cascade) {
          response += biquad.gainDbAt(
            cosW: cosW,
            sinW: sinW,
            cos2W: cos2W,
            sin2W: sin2W,
          );
        }
        if (response > peak) peak = response;
      }
      frequency *= ratio;
    }
    return peak.clamp(0.0, maxGain * bandsHz.length);
  }

  static List<double> normalizeGains(List<double> gains) {
    if (gains.length == bandsHz.length) return clampGains(gains);
    return List<double>.from(flat);
  }

  static List<int> _changedBandIndices(
    List<double>? previous,
    List<double> gains,
  ) {
    if (previous == null) return List<int>.generate(bandsHz.length, (i) => i);
    final reductions = <int>[];
    final boosts = <int>[];
    for (var i = 0; i < bandsHz.length; i++) {
      if (_gain(previous[i]) == _gain(gains[i])) continue;
      (gains[i] < previous[i] ? reductions : boosts).add(i);
    }
    return [...reductions, ...boosts];
  }

  static String _frequency(double value) => value.toStringAsFixed(1);
  static String _gain(double value) => value.toStringAsFixed(2);
  static String _number(double value) => value.toStringAsFixed(1);
}

final class _Biquad {
  const _Biquad({
    required this.a0,
    required this.a1,
    required this.a2,
    required this.b0,
    required this.b1,
    required this.b2,
  });

  factory _Biquad.peaking({
    required double sampleRate,
    required double center,
    required double widthOctaves,
    required double gain,
  }) {
    final w0 = 2 * math.pi * center / sampleRate;
    final sinW0 = math.sin(w0);
    final sinhArgument = math.ln2 / 2 * widthOctaves * w0 / sinW0;
    final sinh = (math.exp(sinhArgument) - math.exp(-sinhArgument)) / 2;
    final alpha = sinW0 * sinh;
    final amplitude = Equalizer.amplitude(gain);
    final a1 = -2 * math.cos(w0);
    return _Biquad(
      a0: 1 + alpha / amplitude,
      a1: a1,
      a2: 1 - alpha / amplitude,
      b0: 1 + alpha * amplitude,
      b1: a1,
      b2: 1 - alpha * amplitude,
    );
  }

  final double a0;
  final double a1;
  final double a2;
  final double b0;
  final double b1;
  final double b2;

  double gainDbAt({
    required double cosW,
    required double sinW,
    required double cos2W,
    required double sin2W,
  }) {
    final numeratorReal = b0 + b1 * cosW + b2 * cos2W;
    final numeratorImaginary = -b1 * sinW - b2 * sin2W;
    final denominatorReal = a0 + a1 * cosW + a2 * cos2W;
    final denominatorImaginary = -a1 * sinW - a2 * sin2W;
    final numerator =
        numeratorReal * numeratorReal + numeratorImaginary * numeratorImaginary;
    final denominator =
        denominatorReal * denominatorReal +
        denominatorImaginary * denominatorImaginary;
    return 10 * math.log(numerator / denominator) / math.ln10;
  }
}

enum EqualizerPreset {
  flat('Flat'),
  bass('Bass'),
  treble('Treble'),
  vocal('Vocal'),
  rock('Rock'),
  pop('Pop'),
  jazz('Jazz'),
  classical('Classical'),
  dance('Dance'),
  electronic('Electronic'),
  hipHop('Hip-Hop'),
  acoustic('Acoustic'),
  headphones('Headphones'),
  laptop('Laptop'),
  party('Party'),
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
