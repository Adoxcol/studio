import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/library_providers.dart';

typedef MusicFolderPicker = Future<String?> Function();
final musicFolderPickerProvider = Provider<MusicFolderPicker>(
  (ref) =>
      () => FilePicker.getDirectoryPath(dialogTitle: 'Add music folder'),
);

/// Shares picker/scan ownership between Settings and any docked Library panes.
/// Closing the originating pane does not abandon an already-started scan.
class LibraryFolderActions extends Notifier<bool> {
  bool _disposed = false;
  @override
  bool build() {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  Future<void> addFolder() async {
    if (state || ref.read(libraryScanProvider).active) return;
    final picker = ref.read(musicFolderPickerProvider);
    final scanner = ref.read(libraryScanProvider.notifier);
    state = true;
    try {
      final path = await picker();
      if (!_disposed && path != null && path.trim().isNotEmpty) {
        await scanner.scanFolder(path);
      }
    } finally {
      if (!_disposed) state = false;
    }
  }
}

final libraryFolderActionsProvider =
    NotifierProvider<LibraryFolderActions, bool>(LibraryFolderActions.new);
