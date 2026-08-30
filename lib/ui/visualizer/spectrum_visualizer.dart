import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

/// 32-band FFT spectrum under the cover art.
class SpectrumVisualizer extends StatelessWidget {
  const SpectrumVisualizer({
    super.key,
    required this.playing,
    required this.bands,
    this.barCount = 32,
    this.height = 44,
    this.width = 280,
  });

  final bool playing;
  final List<double> bands;
  final int barCount;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Semantics(
      label: 'Visualizer',
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: SpectrumPainter(
            playing: playing,
            bands: bands,
            barCount: barCount,
            accent: palette.accent,
            rest: palette.hairlineStrong,
          ),
        ),
      ),
    );
  }
}

double idleLevel(int index) {
  final n = index + 1;
  return (0.1 + 0.05 * math.sin(n * 0.73)).clamp(0.06, 0.2);
}

class SpectrumPainter extends CustomPainter {
  const SpectrumPainter({
    required this.playing,
    required this.bands,
    required this.barCount,
    required this.accent,
    required this.rest,
  });

  final bool playing;
  final List<double> bands;
  final int barCount;
  final Color accent;
  final Color rest;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0 || size.height <= 0) return;
    const gap = 2.0;
    final barWidth = ((size.width - gap * (barCount - 1)) / barCount).clamp(
      1.0,
      size.width,
    );
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < barCount; i++) {
      final sample = i < bands.length ? bands[i].clamp(0.0, 1.0) : 0.0;
      final level =
          playing && bands.isNotEmpty ? math.max(0.08, sample) : idleLevel(i);
      final barHeight = math.max(2.0, size.height * level);
      final x = i * (barWidth + gap);
      final y = size.height - barHeight;
      paint.color = Color.lerp(rest, accent, playing ? level : 0)!;
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(SpectrumPainter old) {
    return old.playing != playing ||
        old.barCount != barCount ||
        old.accent != accent ||
        old.rest != rest ||
        !listEquals(old.bands, bands);
  }
}
