import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';

class ScanNotice extends ConsumerWidget {
  const ScanNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(libraryScanProvider);
    if (!scan.active) return const SizedBox.shrink();
    final palette = StudioPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.bg,
          border: Border.all(color: palette.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scanning',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (scan.folderLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  scan.folderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                scan.detail,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
              const SizedBox(height: 10),
              LibraryTextAction(
                label: 'Stop',
                onTap: () => ref.read(libraryScanProvider.notifier).stop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
