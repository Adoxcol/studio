import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/providers/playable_resolver.dart';

/// Resolves a Subsonic / Navidrome track to an authenticated streaming HTTP(S) URI.
class SubsonicPlayableProvider implements PlayableResolver {
  SubsonicPlayableProvider({SubsonicClient? client, this.clientGetter})
    : _client = client;

  final SubsonicClient? _client;
  final SubsonicClient? Function()? clientGetter;

  @override
  String get sourceId => TrackLocator.subsonic;

  @override
  Future<Uri> resolve(TrackLocator locator) async {
    if (locator.source != sourceId) {
      throw ArgumentError.value(
        locator.source,
        'source',
        'SubsonicPlayableProvider only handles "${TrackLocator.subsonic}" locators',
      );
    }

    final loc = locator.locator;
    // If already an absolute URI
    if (loc.startsWith('http://') || loc.startsWith('https://')) {
      return Uri.parse(loc);
    }

    final client = _client ?? clientGetter?.call();
    if (client == null) {
      throw StateError('Subsonic server is not connected');
    }

    return client.buildStreamUri(loc);
  }
}
