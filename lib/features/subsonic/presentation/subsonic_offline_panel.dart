import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/byte_format.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_providers.dart';
import 'package:studio/theming/studio_palette.dart';

/// Offline storage summary and bulk controls for the Navidrome screen.
class SubsonicOfflinePanel extends ConsumerWidget {
  const SubsonicOfflinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineDownloadsProvider);
    if (!state.available) return const SizedBox.shrink();
    final palette = StudioPalette.of(context);
    final muted = TextStyle(fontSize: 12, color: palette.inkMuted);
    final notifier = ref.read(offlineDownloadsProvider.notifier);
    final active = state.active;
    final progress = active.values.whereType<double>().firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Offline', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          state.downloaded.isEmpty
              ? 'No tracks downloaded. Right-click a Navidrome track, or select several in the Library, and choose Download for offline.'
              : '${state.downloaded.length} ${state.downloaded.length == 1 ? 'track' : 'tracks'} available offline · ${formatBytes(state.totalBytes)}',
          key: const ValueKey('offline-summary'),
          style: muted,
        ),
        if (active.isNotEmpty) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            'Downloading ${active.length} ${active.length == 1 ? 'track' : 'tracks'}…',
            style: muted,
          ),
        ],
        if (state.failed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '${state.failed.length} failed: ${state.failed.values.first}',
            style: muted,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (active.isNotEmpty)
              OutlinedButton.icon(
                key: const ValueKey('offline-cancel-all'),
                onPressed: () {
                  for (final id in active.keys.toList()) {
                    notifier.cancel(id);
                  }
                },
                icon: const Icon(Icons.close),
                label: const Text('Cancel downloads'),
              ),
            OutlinedButton.icon(
              key: const ValueKey('offline-remove-all'),
              onPressed: state.totalBytes == 0 && active.isEmpty
                  ? null
                  : () => _confirmRemoveAll(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove all downloads'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmRemoveAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove all downloads?'),
        content: const Text(
          'Offline copies are deleted from this computer. The tracks stay on your server and can still be streamed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('offline-remove-all-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(offlineDownloadsProvider.notifier).removeAll();
    }
  }
}
