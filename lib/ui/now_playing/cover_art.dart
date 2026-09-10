import 'dart:io';

import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({super.key, this.path, required this.size});

  final String? path;
  final double size;

  /// Reuse a small set of decode sizes while resizing panes. Both axes are
  /// bounded; fit preserves non-square artwork instead of stretching it.
  static int decodeExtent(double size, double pixelRatio) {
    final pixels = (size * pixelRatio).ceil();
    for (final extent in const [64, 128, 256, 512, 1024, 1536, 2048]) {
      if (pixels <= extent) return extent;
    }
    return 2048;
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final file = path == null ? null : File(path!);
    if (file != null) {
      final extent = decodeExtent(size, MediaQuery.devicePixelRatioOf(context));
      return Image(
        image: ResizeImage(
          FileImage(file),
          width: extent,
          height: extent,
          policy: ResizeImagePolicy.fit,
        ),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _Placeholder(size: size, palette: palette),
      );
    }
    return _Placeholder(size: size, palette: palette);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size, required this.palette});

  final double size;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.artSwatch,
        border: Border.all(color: palette.hairlineStrong),
      ),
    );
  }
}
