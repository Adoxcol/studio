/// Tray / media-key actions. Kept free of plugins so tests can cover labels.
enum DesktopTransport { playPause, next, previous, show, quit }

String desktopPlayPauseLabel(bool playing) => playing ? 'Pause' : 'Play';

String desktopTrayTooltip({
  required bool hasTrack,
  required bool playing,
  required String title,
  String? artist,
}) {
  if (!hasTrack) return 'Studio';
  final status = playing ? 'Playing' : 'Paused';
  final who = artist == null || artist.isEmpty ? title : '$title — $artist';
  return '$status · $who';
}

DesktopTransport? desktopTransportForMenuKey(String? key) {
  return switch (key) {
    'playPause' => DesktopTransport.playPause,
    'next' => DesktopTransport.next,
    'previous' => DesktopTransport.previous,
    'show' => DesktopTransport.show,
    'quit' => DesktopTransport.quit,
    _ => null,
  };
}
