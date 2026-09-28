import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/library_source/data/library_source_store.dart';

export 'package:studio/features/library_source/data/library_source_store.dart'
    show LibrarySource;

final librarySourceStoreProvider = Provider<LibrarySourceStore>(
  (ref) => MemoryLibrarySourceStore(),
);

/// The source the user picked, or null if they never have.
class LibrarySourceNotifier extends Notifier<LibrarySource?> {
  @override
  LibrarySource? build() => ref.watch(librarySourceStoreProvider).load();

  void select(LibrarySource source) {
    if (state == source) return;
    state = source;
    ref.read(librarySourceStoreProvider).save(source);
  }
}

final librarySourceProvider =
    NotifierProvider<LibrarySourceNotifier, LibrarySource?>(
      LibrarySourceNotifier.new,
    );

/// The source actually shown. Without a Navidrome server it is always this
/// computer; with one and no local folders, Navidrome is the default until
/// the user picks.
LibrarySource effectiveLibrarySource({
  required LibrarySource? chosen,
  required bool hasLocalFolders,
  required bool hasNavidrome,
}) {
  if (!hasNavidrome) return LibrarySource.local;
  return chosen ??
      (hasLocalFolders ? LibrarySource.local : LibrarySource.navidrome);
}
