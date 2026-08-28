/// Where a playable item comes from. Playback never switches on this —
/// only [PlayableResolver] implementations do.
class TrackLocator {
  const TrackLocator({required this.source, required this.locator});

  /// e.g. `local`. Spotify would be a different source id later.
  final String source;

  /// Source-specific id: a filesystem path for [kLocalSource].
  final String locator;

  static const local = 'local';
}

/// Turns a [TrackLocator] into a playable [Uri] for the audio engine.
abstract interface class PlayableResolver {
  String get sourceId;

  Future<Uri> resolve(TrackLocator locator);
}
