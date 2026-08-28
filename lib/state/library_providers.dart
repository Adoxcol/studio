import 'dart:async';

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

class LibraryScanNotifier extends Notifier<bool> {
  Future<void> _inflight = Future.value();

  @override
  bool build() => false;

  Future<void> scanFolder(String path) {
    return _run(() => ref.read(folderScannerProvider).scan(path));
  }

  Future<void> rescanKnown() async {
    final folders = await ref.read(studioDatabaseProvider).allFolders();
    if (folders.isEmpty) return;
    await _run(() => ref.read(folderScannerProvider).rescanKnown());
  }

  Future<void> _run(Future<int> Function() work) async {
    final previous = _inflight;
    final gate = Completer<void>();
    _inflight = gate.future;
    await previous;
    state = true;
    try {
      await work();
    } finally {
      state = false;
      gate.complete();
    }
  }
}

final libraryScanProvider = NotifierProvider<LibraryScanNotifier, bool>(
  LibraryScanNotifier.new,
);

/// Starts a background rescan of known folders once the shell is mounted.
final libraryBootstrapProvider = FutureProvider<void>((ref) {
  return ref.read(libraryScanProvider.notifier).rescanKnown();
});
