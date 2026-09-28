import 'package:flutter/material.dart';
import 'package:studio/theming/genre_color.dart';
import 'package:studio/theming/studio_palette.dart';

/// A genre name with its colour, for places that list genres inline.
class GenreChip extends StatelessWidget {
  const GenreChip(this.genre, {super.key});

  final String genre;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final colors = genreColors(genre, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            genre,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.ink),
          ),
        ],
      ),
    );
  }
}
