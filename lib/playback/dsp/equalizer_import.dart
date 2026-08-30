import 'dart:convert';
import 'dart:math' as math;

import 'package:studio/playback/dsp/equalizer.dart';

class ImportedEqualizer {
  const ImportedEqualizer({required this.gains, this.preamp = 0});

  final List<double> gains;
  final double preamp;
}

/// Equalizer APO GraphicEQ (AutoEQ / Peace) plus a 10-gain JSON or text dump.
abstract final class EqualizerImport {
  static ImportedEqualizer parse(String text) {
    final graphic = _graphicEq(text);
    if (graphic != null) return graphic;
    final parametric = _parametric(text);
    if (parametric != null) return parametric;
    final json = _json(text);
    if (json != null) return json;
    final numbers = _tenNumbers(text);
    if (numbers != null) return numbers;
    throw FormatException(
      'Not a GraphicEQ, parametric APO, or 10-band equalizer file',
    );
  }

  static ImportedEqualizer? _graphicEq(String text) {
    final header = RegExp(
      r'GraphicEQ:\s*(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (header == null) return null;
    final points = <({double hz, double gain})>[];
    for (final match in RegExp(
      r'(\d+(?:\.\d+)?)\s+([+-]?\d+(?:\.\d+)?)',
    ).allMatches(header.group(1)!)) {
      points.add((
        hz: double.parse(match.group(1)!),
        gain: double.parse(match.group(2)!),
      ));
    }
    if (points.isEmpty) return null;
    points.sort((a, b) => a.hz.compareTo(b.hz));
    return ImportedEqualizer(
      gains: [
        for (final hz in Equalizer.bandsHz)
          Equalizer.clampGain(_atHz(points, hz)),
      ],
      preamp: _preamp(text),
    );
  }

  static ImportedEqualizer? _parametric(String text) {
    final filters = <_ApoFilter>[];
    for (final match in RegExp(
      r'Filter(?:\s+\d+)?:\s+ON\s+(PK|LSC|HSC|LS|HS)\s+Fc\s+(\d+(?:\.\d+)?)\s+Hz\s+Gain\s+([+-]?\d+(?:\.\d+)?)\s+dB(?:\s+Q\s+(\d+(?:\.\d+)?))?',
      caseSensitive: false,
    ).allMatches(text)) {
      filters.add((
        type: match.group(1)!.toUpperCase(),
        hz: double.parse(match.group(2)!),
        gain: double.parse(match.group(3)!),
        q: double.parse(match.group(4) ?? '1.41'),
      ));
    }
    if (filters.isEmpty) return null;
    const fs = 48000.0;
    return ImportedEqualizer(
      gains: [
        for (final hz in Equalizer.bandsHz)
          Equalizer.clampGain(_parametricDb(filters, hz, fs)),
      ],
      preamp: _preamp(text),
    );
  }

  static double _parametricDb(List<_ApoFilter> filters, double hz, double fs) {
    var db = 0.0;
    for (final filter in filters) {
      db += _biquadDb(
        type: filter.type,
        hz: hz,
        fs: fs,
        fc: filter.hz,
        gain: filter.gain,
        q: filter.q <= 0 ? 1.41 : filter.q,
      );
    }
    return db;
  }

  static double _biquadDb({
    required String type,
    required double hz,
    required double fs,
    required double fc,
    required double gain,
    required double q,
  }) {
    final a = math.pow(10, gain / 40).toDouble();
    final w0 = 2 * math.pi * fc / fs;
    final cosw = math.cos(w0);
    final sinw = math.sin(w0);
    final alpha = sinw / (2 * q);
    late final double b0;
    late final double b1;
    late final double b2;
    late final double a0;
    late final double a1;
    late final double a2;
    switch (type) {
      case 'LSC':
      case 'LS':
        final sqrtA = math.sqrt(a);
        b0 = a * ((a + 1) - (a - 1) * cosw + 2 * sqrtA * alpha);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosw);
        b2 = a * ((a + 1) - (a - 1) * cosw - 2 * sqrtA * alpha);
        a0 = (a + 1) + (a - 1) * cosw + 2 * sqrtA * alpha;
        a1 = -2 * ((a - 1) + (a + 1) * cosw);
        a2 = (a + 1) + (a - 1) * cosw - 2 * sqrtA * alpha;
      case 'HSC':
      case 'HS':
        final sqrtA = math.sqrt(a);
        b0 = a * ((a + 1) + (a - 1) * cosw + 2 * sqrtA * alpha);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosw);
        b2 = a * ((a + 1) + (a - 1) * cosw - 2 * sqrtA * alpha);
        a0 = (a + 1) - (a - 1) * cosw + 2 * sqrtA * alpha;
        a1 = 2 * ((a - 1) - (a + 1) * cosw);
        a2 = (a + 1) - (a - 1) * cosw - 2 * sqrtA * alpha;
      default:
        b0 = 1 + alpha * a;
        b1 = -2 * cosw;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cosw;
        a2 = 1 - alpha / a;
    }
    final w = 2 * math.pi * hz / fs;
    final z1r = math.cos(w);
    final z1i = -math.sin(w);
    final z2r = math.cos(2 * w);
    final z2i = -math.sin(2 * w);
    final numR = b0 / a0 + (b1 / a0) * z1r + (b2 / a0) * z2r;
    final numI = (b1 / a0) * z1i + (b2 / a0) * z2i;
    final denR = 1 + (a1 / a0) * z1r + (a2 / a0) * z2r;
    final denI = (a1 / a0) * z1i + (a2 / a0) * z2i;
    final mag2 = (numR * numR + numI * numI) / (denR * denR + denI * denI);
    if (mag2 <= 0) return 0;
    return 20 * math.log(math.sqrt(mag2)) / math.ln10;
  }

  static ImportedEqualizer? _json(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return _fromGains(decoded, 0);
      }
      if (decoded is Map) {
        final raw = decoded['gains'] ?? decoded['bands'];
        if (raw is! List) return null;
        final preamp = (decoded['preamp'] as num?)?.toDouble() ?? 0;
        return _fromGains(raw, preamp);
      }
    } on Object {
      return null;
    }
    return null;
  }

  static ImportedEqualizer? _tenNumbers(String text) {
    final values = <double>[];
    for (final match in RegExp(
      r'[+-]?\d+(?:\.\d+)?',
    ).allMatches(text.replaceAll(',', ' '))) {
      values.add(double.parse(match.group(0)!));
    }
    if (values.length != Equalizer.bandsHz.length) return null;
    return ImportedEqualizer(gains: Equalizer.clampGains(values));
  }

  static ImportedEqualizer? _fromGains(List<dynamic> raw, double preamp) {
    if (raw.length != Equalizer.bandsHz.length) return null;
    final gains = <double>[];
    for (final value in raw) {
      if (value is! num) return null;
      gains.add(value.toDouble());
    }
    return ImportedEqualizer(
      gains: Equalizer.clampGains(gains),
      preamp: Equalizer.clampGain(preamp),
    );
  }

  static double _preamp(String text) {
    final match = RegExp(
      r'Preamp:\s*([+-]?\d+(?:\.\d+)?)\s*dB',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return 0;
    return Equalizer.clampGain(double.parse(match.group(1)!));
  }

  static double _atHz(List<({double hz, double gain})> points, double hz) {
    if (hz <= points.first.hz) return points.first.gain;
    if (hz >= points.last.hz) return points.last.gain;
    for (var i = 0; i < points.length - 1; i++) {
      final left = points[i];
      final right = points[i + 1];
      if (hz < left.hz || hz > right.hz) continue;
      if (left.hz == right.hz) return left.gain;
      final t = (math.log(hz) - math.log(left.hz)) /
          (math.log(right.hz) - math.log(left.hz));
      return left.gain + t * (right.gain - left.gain);
    }
    return 0;
  }
}

typedef _ApoFilter = ({String type, double hz, double gain, double q});
