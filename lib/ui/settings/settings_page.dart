import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Appearance, playback, and sound land here in later phases.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
          ),
        ],
      ),
    );
  }
}
