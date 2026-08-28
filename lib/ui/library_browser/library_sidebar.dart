import 'package:flutter/material.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:path/path.dart' as p;

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.expanded,
    required this.folders,
    required this.artists,
    required this.selectedArtist,
    required this.onToggle,
    required this.onSelectArtist,
    required this.onRemoveFolder,
  });

  static const double width = 168;
  static const double collapsedWidth = 28;

  final bool expanded;
  final List<LibraryFolder> folders;
  final List<LibraryGroup> artists;
  final String? selectedArtist;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelectArtist;
  final ValueChanged<int> onRemoveFolder;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: expanded ? width : collapsedWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.hairline)),
      ),
      child: expanded ? _expanded(context, palette) : _collapsed(palette),
    );
  }

  Widget _collapsed(StudioPalette palette) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: GestureDetector(
          onTap: onToggle,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(Icons.chevron_right, size: 18, color: palette.inkMuted),
          ),
        ),
      ),
    );
  }

  Widget _expanded(BuildContext context, StudioPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'LIBRARY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.inkMuted,
                    letterSpacing: 1.4,
                    fontSize: 11,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggle,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: palette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (folders.isNotEmpty) ...[
                _SectionLabel(text: 'FOLDERS'),
                for (final folder in folders)
                  _FolderRow(
                    label: p.basename(folder.path),
                    tooltip: folder.path,
                    onRemove: () => onRemoveFolder(folder.id),
                  ),
                const SizedBox(height: 12),
              ],
              _SectionLabel(text: 'ARTISTS'),
              for (final artist in artists)
                _ArtistRow(
                  name: artist.name,
                  selected: artist.name == selectedArtist,
                  onTap: () => onSelectArtist(artist.name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.inkMuted,
          letterSpacing: 1.4,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.label,
    required this.tooltip,
    required this.onRemove,
  });

  final String label;
  final String tooltip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: tooltip,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'Remove folder',
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: palette.inkMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                child: selected
                    ? Icon(Icons.check, size: 12, color: palette.accent)
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? palette.ink : palette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
