import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/features/track_details/presentation/detail_panels.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/ui/layout/studio_dock_theme.dart';
import 'package:studio/ui/library_browser/library_page.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/queue/queue_page.dart';

/// Library | (Now Playing / Artist / Album / Track tabs) above Queue.
class StudioWorkspace extends ConsumerStatefulWidget {
  const StudioWorkspace({super.key});

  @override
  ConsumerState<StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends ConsumerState<StudioWorkspace> {
  late final DockingLayout _layout = DockingLayout(
    root: DockingRow([
      DockingItem(
        id: 'library',
        name: 'Library',
        widget: const LibraryPage(),
        closable: false,
        keepAlive: true,
        weight: 0.42,
        minimalWeight: 0.22,
      ),
      DockingColumn([
        DockingTabs(
          [
            DockingItem(
              id: 'nowPlaying',
              name: 'Now Playing',
              widget: const NowPlayingPage(),
              closable: false,
              keepAlive: true,
            ),
            DockingItem(
              id: 'artist',
              name: 'Artist',
              widget: const ArtistDetailPanel(),
              closable: false,
              keepAlive: true,
            ),
            DockingItem(
              id: 'album',
              name: 'Album',
              widget: const AlbumDetailPanel(),
              closable: false,
              keepAlive: true,
            ),
            DockingItem(
              id: 'track',
              name: 'Track',
              widget: const TrackDetailPanel(),
              closable: false,
              keepAlive: true,
            ),
          ],
          weight: 0.64,
          minimalWeight: 0.28,
        ),
        DockingItem(
          id: 'queue',
          name: 'Queue',
          widget: const QueuePage(),
          closable: false,
          keepAlive: true,
          weight: 0.36,
          minimalWeight: 0.16,
        ),
      ], weight: 0.58),
    ]),
  );

  void _activate(String id) {
    final item = _layout.findDockingItem(id);
    if (item == null) return;
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
