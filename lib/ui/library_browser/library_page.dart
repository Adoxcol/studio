import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Library', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Library is empty. Local files will show up here.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}
