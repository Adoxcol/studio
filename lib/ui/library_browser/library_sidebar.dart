import 'package:flutter/material.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/theming/studio_palette.dart';

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar({
    super.key,
    required this.expanded,
    required this.artists,
    required this.selectedArtist,
    required this.onToggle,
    required this.onSelectArtist,
  });

  static const double width = 168;
  static const double collapsedWidth = 28;

  final bool expanded;
  final List<LibraryGroup> artists;
  final String? selectedArtist;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelectArtist;

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
                  'ARTISTS',
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
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              final selected = artist.name == selectedArtist;
              return GestureDetector(
                onTap: () => onSelectArtist(artist.name),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: selected
                              ? Icon(
                                  Icons.check,
                                  size: 12,
                                  color: palette.accent,
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: selected
                                      ? palette.ink
                                      : palette.inkMuted,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
