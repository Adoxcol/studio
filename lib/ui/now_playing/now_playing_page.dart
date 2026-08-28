import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class NowPlayingPage extends StatelessWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 280, height: 280, color: palette.artSwatch),
            const SizedBox(height: 28),
            Text(
              'Nothing playing',
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'now playing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.inkMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
