import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:studio/features/track_details/presentation/detail_panels.dart';
import 'package:studio/ui/library_browser/library_page.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/queue/queue_page.dart';

/// One instance of each widget; adding an open widget moves it to this pane.
enum WorkspaceWidget {
  library('Library', Icons.library_music_outlined),
  nowPlaying('Now Playing', Icons.graphic_eq),
  playbackMode('Playback Mode', Icons.fullscreen),
  queue('Queue', Icons.queue_music),
  artist('Artist', Icons.person_outline),
  album('Album', Icons.album_outlined),
  track('Track', Icons.music_note_outlined);

  const WorkspaceWidget(this.label, this.icon);
  final String label;
  final IconData icon;

  DockingItem create({double? weight, double? minimalWeight}) => DockingItem(
    id: name,
    name: label,
    widget: DeferredWorkspacePanel(
      builder: (_) => switch (this) {
        library => const LibraryPage(),
        nowPlaying => const NowPlayingPage(),
        playbackMode => const PlaybackModeWidget(),
        queue => const QueuePage(),
        artist => const ArtistDetailPanel(),
        album => const AlbumDetailPanel(),
        track => const TrackDetailPanel(),
      },
    ),
    closable: false,
    keepAlive: true,
    weight: weight,
    minimalWeight: minimalWeight,
  );

  static DockingArea defaultLayout() => DockingRow([
    library.create(weight: 0.42, minimalWeight: 0.22),
    DockingColumn([
      DockingTabs(
        [nowPlaying.create(), artist.create(), album.create(), track.create()],
        weight: 0.64,
        minimalWeight: 0.28,
      ),
      queue.create(weight: 0.36, minimalWeight: 0.16),
    ], weight: 0.58),
  ]);
}

/// Unopened tabs allocate no panel state. Once opened, docking retains the
/// state while TickerMode pauses animations and Riverpod UI subscriptions.
class DeferredWorkspacePanel extends StatefulWidget {
  const DeferredWorkspacePanel({super.key, required this.builder});
  final WidgetBuilder builder;

  @override
  State<DeferredWorkspacePanel> createState() => _DeferredWorkspacePanelState();
}

class _DeferredWorkspacePanelState extends State<DeferredWorkspacePanel> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _opened = _opened || TickerMode.valuesOf(context).enabled;
  }

  @override
  Widget build(BuildContext context) =>
      _opened ? widget.builder(context) : const SizedBox.shrink();
}
