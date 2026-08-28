import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scan_progress.dart';
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

final libraryFoldersProvider = StreamProvider<List<LibraryFolder>>((ref) {
  return ref.watch(studioDatabaseProvider).watchFolders();
});

class LibraryScanNotifier extends Notifier<ScanProgress> {
  Future<void> _inflight = Future.value();
  var _cancelRequested = false;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  ScanProgress build() => ScanProgress.idle;

  void stop() => _cancelRequested = true;

  Future<void> scanFolder(String path) {
    return _run(
      () => ref
          .read(folderScannerProvider)
          .scan(path, isCancelled: () => _cancelRequested, onProgress: _push),
    );
  }

  Future<void> rescanKnown() async {
    final folders = await ref.read(studioDatabaseProvider).allFolders();
    if (folders.isEmpty) return;
    await _run(
      () => ref
          .read(folderScannerProvider)
          .rescanKnown(isCancelled: () => _cancelRequested, onProgress: _push),
    );
  }

  Future<void> removeFolder(int folderId) async {
    if (state.active) return;
    await ref.read(studioDatabaseProvider).deleteFolder(folderId);
  }

  void _push(ScanProgress progress) {
    final now = DateTime.now();
    if (progress.processed != progress.total &&
        now.difference(_lastPush) < const Duration(milliseconds: 80)) {
      return;
    }
    _lastPush = now;
    state = progress;
  }

  Future<void> _run(Future<ScanResult> Function() work) async {
    final previous = _inflight;
    final gate = Completer<void>();
    _inflight = gate.future;
    await previous;
    _cancelRequested = false;
    state = const ScanProgress(active: true);
    try {
      await work();
    } finally {
      state = ScanProgress.idle;
      gate.complete();
    }
  }
}

final libraryScanProvider = NotifierProvider<LibraryScanNotifier, ScanProgress>(
  LibraryScanNotifier.new,
);

/// Starts a background rescan of known folders once the shell is mounted.
final libraryBootstrapProvider = FutureProvider<void>((ref) {
  return ref.read(libraryScanProvider.notifier).rescanKnown();
});
