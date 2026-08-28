import 'package:studio/providers/playable_resolver.dart';

/// Resolves a local library file to a `file:` URI. Playback never sees the path.
class LocalFileProvider implements PlayableResolver {
  const LocalFileProvider();

  @override
  String get sourceId => TrackLocator.local;

  @override
  Future<Uri> resolve(TrackLocator locator) async {
    if (locator.source != sourceId) {
      throw ArgumentError.value(
        locator.source,
        'source',
        'LocalFileProvider only handles "${TrackLocator.local}" locators',
      );
    }
    final path = locator.locator;
    final windows = path.contains(r'\') || (path.length >= 2 && path[1] == ':');
    return Uri.file(path, windows: windows);
  }
}
