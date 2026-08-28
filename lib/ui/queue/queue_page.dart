import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Text(
        'Queue is empty.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      ),
    );
  }
}
