import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/library_folders/presentation/library_folder_actions.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_palette.dart';

/// The same live folder list is used in Library and Settings. Embedded mode
/// participates in Settings' outer scroll; the docked tab owns its own scroll.
class LibraryFoldersPanel extends ConsumerWidget {
  const LibraryFoldersPanel({
    super.key,
    this.embedded = false,
    this.query = '',
    this.onOpen,
  });
  final bool embedded;
  final String query;
  final ValueChanged<LibraryFolder>? onOpen;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(libraryFolderActionsProvider.notifier);
    try {
      await actions.addFolder();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not add this folder. Check that it exists and is accessible.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    LibraryFolder folder,
  ) async {
    final scanner = ref.read(libraryScanProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove music folder?'),
        content: Text(
          '${folder.path}\n\nIts tracks will be removed from Studio’s library. Your music files will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // A scan may have started in another pane while confirmation was open.
    if (ref.read(libraryScanProvider).active ||
        ref.read(libraryFolderActionsProvider)) {
      return;
    }
    try {
      await scanner.removeFolder(folder.id);
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove this folder. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final folders = ref.watch(libraryFoldersProvider);
    final busy =
        ref.watch(libraryFolderActionsProvider) ||
        ref.watch(libraryScanProvider.select((s) => s.active));
    final needle = query.trim().toLowerCase();
    final body = folders.when(
      loading: () => const Text('Loading folders…'),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Could not load your music folders.'),
          TextButton(
            onPressed: () => ref.invalidate(libraryFoldersProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (all) {
        final visible = all
            .where((f) => f.path.toLowerCase().contains(needle))
            .toList();
        if (visible.isEmpty) {
          return Text(
            all.isEmpty
                ? 'No music folders yet. Add a folder to start your library.'
                : 'No matching folders.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
          );
        }
        return ListView.separated(
          key: const ValueKey('music-folder-list'),
          shrinkWrap: embedded,
          physics: embedded ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.only(bottom: embedded ? 16 : 72),
          itemCount: visible.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: palette.hairline),
          itemBuilder: (context, index) {
            final folder = visible[index];
            final name = p.basename(p.normalize(folder.path));
            return ListTile(
              key: ValueKey('music-folder-${folder.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.folder_outlined, color: palette.inkMuted),
              title: Text(
                name.isEmpty ? folder.path : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Tooltip(
                message: folder.path,
                child: Text(
                  folder.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                ),
              ),
              onTap: onOpen == null ? null : () => onOpen!(folder),
              trailing: IconButton(
                tooltip: 'Remove folder',
                onPressed: busy ? null : () => _remove(context, ref, folder),
                icon: const Icon(Icons.close, size: 18),
              ),
            );
          },
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Music folders',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            TextButton.icon(
              key: const ValueKey('add-music-folder'),
              onPressed: busy ? null : () => _add(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Add folder'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (embedded)
          body
        else
          Expanded(
            child: Align(alignment: Alignment.topLeft, child: body),
          ),
      ],
    );
  }
}
