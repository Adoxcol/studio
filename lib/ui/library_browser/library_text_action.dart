import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

class LibraryTextAction extends StatelessWidget {
  const LibraryTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.muted = false,
    this.showChevron = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool muted;
  final bool showChevron;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final color = !enabled
        ? palette.inkMuted
        : muted
        ? palette.inkMuted
        : palette.ink;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
            if (showChevron) ...[
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
