import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/track_actions/track_actions_menu.dart';

/// Physical album jacket and grooved vinyl record component.
class VinylSleeve extends ConsumerWidget {
  const VinylSleeve({
    super.key,
    required this.artworkPath,
    required this.size,
    this.coverMode = PlaybackCoverMode.vinylSleeve,
    this.track,
  });

  final String? artworkPath;
  final double size;
  final PlaybackCoverMode coverMode;
  final Track? track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (coverMode == PlaybackCoverMode.original) {
      return _OriginalCover(
        artworkPath: artworkPath,
        size: size,
        palette: palette,
        isDark: isDark,
        track: track,
      );
    }

    if (coverMode == PlaybackCoverMode.fullBleed) {
      return _FullBleedCover(
        artworkPath: artworkPath,
        size: size,
        palette: palette,
        isDark: isDark,
        track: track,
      );
    }

    final sleeveSize = size;
    final discSize = sleeveSize * 0.94;
    final discOffset = sleeveSize * 0.36;
    final totalWidth = sleeveSize + discOffset;

    return Center(
      child: SizedBox(
        width: totalWidth,
        height: sleeveSize,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Vinyl Record peeking out from the sleeve
            Positioned(
              left: discOffset,
              top: (sleeveSize - discSize) / 2,
              child: _VinylDisc(
                artworkPath: artworkPath,
                discSize: discSize,
                isDark: isDark,
              ),
            ),

            // Physical album jacket / sleeve in front of the disc
            Positioned(
              left: 0,
              top: 0,
              width: sleeveSize,
              height: sleeveSize,
              child: _PhysicalAlbumJacket(
                artworkPath: artworkPath,
                size: sleeveSize,
                palette: palette,
                isDark: isDark,
                track: track,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginalCover extends StatelessWidget {
  const _OriginalCover({
    required this.artworkPath,
    required this.size,
    required this.palette,
    required this.isDark,
    required this.track,
  });

  final String? artworkPath;
  final double size;
  final StudioPalette palette;
  final bool isDark;
  final Track? track;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArt(path: artworkPath, size: size),
              if (track != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: TrackActionsButton(
                      track: track!,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullBleedCover extends StatelessWidget {
  const _FullBleedCover({
    required this.artworkPath,
    required this.size,
    required this.palette,
    required this.isDark,
    required this.track,
  });

  final String? artworkPath;
  final double size;
  final StudioPalette palette;
  final bool isDark;
  final Track? track;

  @override
  Widget build(BuildContext context) {
    // Full bleed artwork expands with widescreen 1:1 or edge ratio, 0 border radius or subtle 2px rounding,
    // strong shadow and high visual presence
    final bleedSize = size * 1.14;
    return Center(
      child: Container(
        width: bleedSize,
        height: bleedSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.28),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: palette.accent.withValues(alpha: isDark ? 0.22 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArt(path: artworkPath, size: bleedSize),
              if (track != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: TrackActionsButton(
                      track: track!,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhysicalAlbumJacket extends StatelessWidget {
  const _PhysicalAlbumJacket({
    required this.artworkPath,
    required this.size,
    required this.palette,
    required this.isDark,
    required this.track,
  });

  final String? artworkPath;
  final double size;
  final StudioPalette palette;
  final bool isDark;
  final Track? track;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          // Ambient soft drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.18),
            blurRadius: 26,
            offset: const Offset(-2, 12),
          ),
          // Directional shadow cast to bottom right
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? const Color(0x33FFFFFF)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Artwork
            CoverArt(path: artworkPath, size: size),

            // Subtle paper spine edge highlight on the left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.12 : 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Subtle inner sleeve shadow on the right opening edge
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: isDark ? 0.35 : 0.20),
                    ],
                  ),
                ),
              ),
            ),

            // Action button menu top right
            if (track != null)
              Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.50),
                    shape: BoxShape.circle,
                  ),
                  child: TrackActionsButton(track: track!, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VinylDisc extends ConsumerWidget {
  const _VinylDisc({
    required this.artworkPath,
    required this.discSize,
    required this.isDark,
  });

  final String? artworkPath;
  final double discSize;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: discSize,
      height: discSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.22),
            blurRadius: 18,
            offset: const Offset(4, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _VinylRecordPainter(isDark: isDark),
        child: Center(
          child: _VinylCenterLabel(
            artworkPath: artworkPath,
            size: discSize * 0.34,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _VinylRecordPainter extends CustomPainter {
  _VinylRecordPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base vinyl body (deep vinyl black with slight radial tint)
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF1E1D1B), Color(0xFF121110), Color(0xFF0C0B0A)],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, basePaint);

    // Subtle edge bevel ring
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x33FFFFFF);
    canvas.drawCircle(center, radius - 0.5, edgePaint);

    // Draw sound groove rings
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final startGroove = radius * 0.40;
    final endGroove = radius * 0.94;
    const grooveStep = 2.8;

    for (double r = startGroove; r < endGroove; r += grooveStep) {
      final intensity = ((math.sin(r * 1.5) + 1) / 2) * 0.045 + 0.015;
      groovePaint.color = Colors.white.withValues(alpha: intensity);
      canvas.drawCircle(center, r, groovePaint);
    }

    // Specular light sheen across the grooves (two opposing conical reflection cones)
    final sheenPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.05, 0.20, 0.35, 0.55, 0.70, 0.85],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Clip sheen to the grooved area
    final sheenPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: endGroove))
      ..addOval(Rect.fromCircle(center: center, radius: startGroove))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(covariant _VinylRecordPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _VinylCenterLabel extends StatelessWidget {
  const _VinylCenterLabel({
    required this.artworkPath,
    required this.size,
    required this.isDark,
  });

  final String? artworkPath;
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final artwork = artworkPath;
    final uri = artwork == null ? null : Uri.tryParse(artwork);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final file = artwork == null || isNetwork ? null : File(artwork);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF242220),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (isNetwork)
              Image.network(
                artwork!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF2E2A27)),
              )
            else if (file != null && file.existsSync())
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF2E2A27)),
              )
            else
              const ColoredBox(color: Color(0xFF2E2A27)),

            // Subtle circular gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.65, 1.0],
                ),
              ),
            ),

            // Spindle hole
            Center(
              child: Container(
                width: size * 0.18,
                height: size * 0.18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF13110F)
                      : const Color(0xFF22201D),
                  border: Border.all(
                    color: const Color(0xFF888888),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
