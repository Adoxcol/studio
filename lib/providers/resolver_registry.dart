import 'package:studio/providers/local_file_provider.dart';
import 'package:studio/providers/playable_resolver.dart';

/// Looks up a resolver by source id. Spotify would register here later.
class ResolverRegistry {
  ResolverRegistry({List<PlayableResolver>? resolvers})
    : _bySource = {
        for (final resolver in resolvers ?? const [LocalFileProvider()])
          resolver.sourceId: resolver,
      };

  final Map<String, PlayableResolver> _bySource;

  Future<Uri> resolve(TrackLocator locator) {
    final resolver = _bySource[locator.source];
    if (resolver == null) {
      throw StateError('No playable resolver for source "${locator.source}"');
    }
    return resolver.resolve(locator);
  }
}
