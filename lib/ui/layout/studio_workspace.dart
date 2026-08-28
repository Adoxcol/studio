import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:studio/ui/layout/studio_dock_theme.dart';
import 'package:studio/ui/library_browser/library_page.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/queue/queue_page.dart';

/// Default dockable workspace: Library | Now Playing / Queue.
class StudioWorkspace extends StatefulWidget {
  const StudioWorkspace({super.key});

  @override
  State<StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends State<StudioWorkspace> {
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
        DockingItem(
          id: 'nowPlaying',
          name: 'Now Playing',
          widget: const NowPlayingPage(),
          closable: false,
          keepAlive: true,
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

  @override
  Widget build(BuildContext context) {
    return StudioDockChrome(
      child: Docking(layout: _layout, maximizableItem: true, draggable: true),
    );
  }
}
