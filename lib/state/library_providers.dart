import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scanner.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/playback/media_kit_engine.dart';
import 'package:studio/providers/resolver_registry.dart';

final studioDatabaseProvider = Provider<StudioDatabase>((ref) {
  throw StateError('studioDatabaseProvider must be overridden in main()');
});

final artworkStoreProvider = Provider<ArtworkStore?>((ref) => null);

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = MediaKitAudioEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final resolverRegistryProvider = Provider<ResolverRegistry>((ref) {
  return ResolverRegistry();
});

final folderScannerProvider = Provider<FolderScanner>((ref) {
  return FolderScanner(
    db: ref.watch(studioDatabaseProvider),
    artwork: ref.watch(artworkStoreProvider),
  );
});

final libraryTracksProvider = StreamProvider<List<Track>>((ref) {
  return ref.watch(studioDatabaseProvider).watchTracks();
});
