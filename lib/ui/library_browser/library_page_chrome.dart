part of 'library_page.dart';

class _LibraryBackButton extends StatelessWidget {
  const _LibraryBackButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Material(
      color: palette.bg,
      elevation: 2,
      shape: CircleBorder(side: BorderSide(color: palette.hairline)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        key: const ValueKey('library-back'),
        tooltip: label,
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_back, size: 20),
        color: palette.ink,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onSearch,
    this.hint = 'Search your library',
    this.trailing,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final String hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxWidth >= 280;
        return Row(
          children: [
            if (showTitle) ...[
              Text(
                'Library',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(width: 24),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: (_) => onSearch(),
                cursorColor: palette.ink,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            if (trailing case final trailing?) ...[
              const SizedBox(width: 16),
              // Shrinks rather than overflowing in a narrow Library pane.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.onSelect,
    this.tabs = LibraryTab.values,
  });

  final LibraryTab selected;
  final ValueChanged<LibraryTab> onSelect;
  final List<LibraryTab> tabs;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Semantics(
                  button: true,
                  label: tab.label,
                  selected: tab == selected,
                  child: GestureDetector(
                    onTap: () => onSelect(tab),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        tab.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tab == selected
                              ? palette.ink
                              : palette.inkMuted,
                          fontWeight: tab == selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks the catalogue the whole Library shows. It sits apart from the tabs
/// so the choice holds while moving between Songs, Artists, Genres, etc.
class _SourceSwitch extends StatelessWidget {
  const _SourceSwitch({required this.selected, required this.onSelect});

  final LibrarySource selected;
  final ValueChanged<LibrarySource> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final source in LibrarySource.values)
            Semantics(
              button: true,
              selected: source == selected,
              label: 'Library source: ${source.label}',
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('library-source-${source.name}'),
                onTap: () => onSelect(source),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: source == selected
                          ? palette.accent.withValues(alpha: 0.18)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      source.label,
                      style: style?.copyWith(
                        color: source == selected
                            ? palette.ink
                            : palette.inkMuted,
                        fontWeight: source == selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.sort,
    required this.order,
    required this.canPlay,
    required this.showSort,
    required this.showView,
    required this.trackLayout,
    required this.onPlayAll,
    required this.onShuffle,
    required this.onCycleSort,
    required this.onToggleOrder,
    required this.onCycleLayout,
    required this.filterCount,
    required this.onFilters,
    this.extras = const [],
  });

  final LibrarySort sort;
  final LibraryOrder order;
  final bool canPlay;
  final bool showSort;
  final bool showView;
  final TrackLayout trackLayout;
  final VoidCallback onPlayAll;
  final VoidCallback onShuffle;
  final VoidCallback onCycleSort;
  final VoidCallback onToggleOrder;
  final VoidCallback onCycleLayout;
  final int filterCount;
  final VoidCallback onFilters;
  final List<Widget> extras;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LibraryTextAction(
          label: 'Play All',
          onTap: onPlayAll,
          enabled: canPlay,
        ),
        LibraryTextAction(label: 'Shuffle', onTap: onShuffle, enabled: canPlay),
        if (showSort) ...[
          LibraryTextAction(
            label: 'Sort: ${sort.label}',
            onTap: onCycleSort,
            muted: true,
            showChevron: true,
          ),
          LibraryTextAction(
            label: 'Order: ${order.labelFor(sort)}',
            onTap: onToggleOrder,
            muted: true,
            showChevron: true,
          ),
        ],
        if (showView)
          LibraryTextAction(
            label: 'View: ${trackLayout.label}',
            onTap: onCycleLayout,
            muted: true,
            showChevron: true,
          ),
        LibraryTextAction(
          key: const ValueKey('library-filters'),
          label: filterCount == 0 ? 'Filters' : 'Filters ($filterCount)',
          onTap: onFilters,
          muted: filterCount == 0,
          showChevron: true,
        ),
        ...extras,
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.palette,
    this.text = 'Library is empty. Local files will show up here.',
  });

  final StudioPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return IconButton(
      tooltip: 'Rescan library',
      onPressed: enabled ? onTap : null,
      icon: const Icon(Icons.refresh, size: 18),
      style: IconButton.styleFrom(
        backgroundColor: palette.bg,
        foregroundColor: palette.ink,
        disabledForegroundColor: palette.inkMuted,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.hairline),
        ),
        fixedSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
