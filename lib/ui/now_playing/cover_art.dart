import 'dart:io';

import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({super.key, this.path, required this.size});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final file = path == null ? null : File(path!);
    if (file != null && file.existsSync()) {
      return Image.file(
        file,
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
