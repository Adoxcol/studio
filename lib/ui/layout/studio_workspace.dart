import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/ui/layout/studio_dock_theme.dart';
import 'package:studio/ui/layout/workspace_widget.dart';
import 'package:studio/theming/studio_palette.dart';

/// Library | (Now Playing / Artist / Album / Track tabs) above Queue.
class StudioWorkspace extends ConsumerStatefulWidget {
  const StudioWorkspace({super.key});

  @override
  ConsumerState<StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends ConsumerState<StudioWorkspace> {
  late final DockingLayout _layout = DockingLayout(
    root: WorkspaceWidget.defaultLayout(),
  );
  bool _menuOpen = false;

  Widget _tabStrip(BuildContext context, DockingArea area, Widget child) {
    return GestureDetector(
      key: ObjectKey(area),
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) =>
          _showWidgetMenu(context, area, details.globalPosition),
      child: child,
    );
  }

  DockingItem _firstItem(DockingArea area) =>
      area is DockingTabs ? area.childAt(0) : area as DockingItem;

  DockingItem _selectedItem(DockingArea area) => area is DockingTabs
      ? area.childAt(area.selectedIndex.clamp(0, area.childrenCount - 1))
      : area as DockingItem;

  Future<void> _showWidgetMenu(
    BuildContext stripContext,
    DockingArea area,
    Offset position,
  ) async {
    if (_menuOpen) return;
    final anchorId = _firstItem(area).id;
    final selected = _selectedItem(area);
    final palette = StudioPalette.of(context);
    final overlay =
        Overlay.of(stripContext).context.findRenderObject()! as RenderBox;
    final here = <String>{
      if (area is DockingTabs)
        for (var i = 0; i < area.childrenCount; i++)
          area.childAt(i).id as String
      else
        (area as DockingItem).id as String,
    };
    _menuOpen = true;
    String? action;
    try {
      action = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
          Rect.fromLTWH(
            overlay.globalToLocal(position).dx,
            overlay.globalToLocal(position).dy,
            0,
            0,
          ),
          Offset.zero & overlay.size,
        ),
        color: palette.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: palette.hairline),
        ),
        items: [
          const PopupMenuItem<String>(
            enabled: false,
            height: 32,
            child: Text('Add widget to this pane'),
          ),
          for (final widget in WorkspaceWidget.values)
            PopupMenuItem<String>(
              key: ValueKey('workspace-add-${widget.name}'),
              value: widget.name,
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: palette.inkMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(widget.label)),
                  const SizedBox(width: 20),
                  if (here.contains(widget.name))
                    Icon(Icons.check, size: 16, color: palette.accent)
                  else if (_layout.findDockingItem(widget.name) != null)
                    Text(
                      'Move here',
                      style: TextStyle(color: palette.inkMuted, fontSize: 11),
                    ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'hide',
            enabled: selected.id != WorkspaceWidget.library.name,
            child: Text('Hide ${selected.name}'),
          ),
          const PopupMenuItem<String>(
            value: 'reset',
            child: Text('Reset layout'),
          ),
        ],
      );
    } finally {
      _menuOpen = false;
    }
    if (!mounted || action == null) return;
    if (action == 'reset') {
      _layout.restore();
      _layout.root = WorkspaceWidget.defaultLayout();
      ref.read(studioNavProvider.notifier).select(StudioDestination.library);
      return;
    }
    if (action == 'hide') {
      final item = _layout.findDockingItem(selected.id);
      if (item == null || item.id == WorkspaceWidget.library.name) return;
      _layout.restore();
      _layout.removeItem(item: item);
      final next =
          _layout.findDockingItem(anchorId) ??
          _layout.findDockingItem(WorkspaceWidget.library.name)!;
      _activate(next.id as String);
      ref
          .read(studioNavProvider.notifier)
          .select(StudioDestination.values.byName(next.id as String));
      return;
    }
    // Resolve fresh targets: navigation may have changed while the menu was open.
    final anchor = _layout.findDockingItem(anchorId);
    if (anchor == null) return;
    final target = _layout.findDockingTabsWithItem(anchorId) ?? anchor;
    final existing = _layout.findDockingItem(action);
    _layout.restore();
    if (existing == null) {
      _layout.addItemOn(
        newItem: WorkspaceWidget.values.byName(action).create(),
        targetArea: target as DropArea,
        dropIndex: target is DockingTabs ? target.childrenCount : 1,
      );
    } else if (existing != anchor && existing.parent != target) {
      _layout.moveItem(
        draggedItem: existing,
        targetArea: target as DropArea,
        dropIndex: target is DockingTabs ? target.childrenCount : 1,
      );
    }
    _activate(action);
    ref
        .read(studioNavProvider.notifier)
        .select(StudioDestination.values.byName(action));
  }

  void _activate(String id) {
    var item = _layout.findDockingItem(id);
    if (item == null) {
      final kind = WorkspaceWidget.values
          .where((value) => value.name == id)
          .firstOrNull;
      if (kind == null) return;
      final anchor =
          _layout.findDockingItem('nowPlaying') ??
          _layout.findDockingItem('library')!;
      final target = _layout.findDockingTabsWithItem(anchor.id) ?? anchor;
      _layout.restore();
      item = kind.create();
      _layout.addItemOn(
        newItem: item,
        targetArea: target as DropArea,
        dropIndex: target is DockingTabs ? target.childrenCount : 1,
      );
    }
    final tabs = _layout.findDockingTabsWithItem(id);
    if (tabs != null) {
      for (var index = 0; index < tabs.childrenCount; index++) {
        if (tabs.childAt(index).id == id) {
          tabs.selectedIndex = index;
        }
      }
    }
    final maximized = _layout.maximizedArea;
    if (maximized != null && maximized != item && maximized != tabs) {
      _layout.restore();
    } else {
      _layout.rebuild();
    }
  }

  @override
  void dispose() {
    _layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(studioNavProvider, (_, destination) {
      if (destination != StudioDestination.settings) {
        _activate(destination.name);
      }
    });
    ref.listen(detailSelectionProvider, (_, selection) {
      if (selection.trackId == null) return;
      _activate('track');
      ref.read(studioNavProvider.notifier).select(StudioDestination.track);
    });
    return StudioDockChrome(
      child: Docking(
        layout: _layout,
        tabsAreaBuilder: _tabStrip,
        maximizableItem: true,
        draggable: true,
        onItemSelection: (item) {
          final destination = StudioDestination.values
              .where((destination) => destination.name == item.id)
              .firstOrNull;
          if (destination != null) {
            ref.read(studioNavProvider.notifier).select(destination);
          }
        },
      ),
    );
  }
}
