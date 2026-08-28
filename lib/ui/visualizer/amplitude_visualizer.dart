import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

/// v1 visualizer: amplitude-envelope bars driven by playback position.
/// Not a PCM/FFT tap — that is a later phase.
class AmplitudeVisualizer extends StatelessWidget {
  const AmplitudeVisualizer({
    super.key,
    required this.playing,
    required this.position,
    this.barCount = 32,
    this.height = 44,
    this.width = 280,
  });

  final bool playing;
  final Duration position;
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
          painter: AmplitudePainter(
            playing: playing,
            position: position,
            barCount: barCount,
            accent: palette.accent,
            rest: palette.hairlineStrong,
          ),
        ),
      ),
    );
  }
}

double amplitudeAt({
  required int index,
  required Duration position,
  required bool playing,
}) {
  final t = position.inMilliseconds / 1000.0;
  final n = index + 1;
  final idle = 0.1 + 0.05 * math.sin(n * 0.73);
  if (!playing) return idle.clamp(0.06, 0.2);
  final wave = 0.5 + 0.5 * math.sin(t * (1.4 + n * 0.13) + n * 0.41);
  final pulse = 0.55 + 0.45 * math.sin(t * 2.1);
  return (0.16 + 0.84 * wave * pulse).clamp(0.08, 1.0);
}

class AmplitudePainter extends CustomPainter {
  const AmplitudePainter({
    required this.playing,
    required this.position,
    required this.barCount,
    required this.accent,
    required this.rest,
  });

  final bool playing;
  final Duration position;
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
      final level = amplitudeAt(index: i, position: position, playing: playing);
      final barHeight = math.max(2.0, size.height * level);
      final x = i * (barWidth + gap);
      final y = size.height - barHeight;
      paint.color = Color.lerp(rest, accent, playing ? level : 0)!;
      canvas.drawRect(Rect.fromLTWH(x, y, barWidth, barHeight), paint);
    }
  }

  @override
  bool shouldRepaint(AmplitudePainter old) {
    return old.playing != playing ||
        old.position != position ||
        old.barCount != barCount ||
        old.accent != accent ||
        old.rest != rest;
  }
}
