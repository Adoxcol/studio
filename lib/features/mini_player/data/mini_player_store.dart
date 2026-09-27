import 'dart:convert';
import 'dart:io';

/// Remembers whether the mini player floats above other windows.
abstract class MiniPlayerStore {
  bool loadPinned();
  void savePinned(bool pinned);
}

class MemoryMiniPlayerStore implements MiniPlayerStore {
  MemoryMiniPlayerStore([this.pinned = true]);

  bool pinned;

  @override
  bool loadPinned() => pinned;

  @override
  void savePinned(bool value) => pinned = value;
}

class FileMiniPlayerStore implements MiniPlayerStore {
  FileMiniPlayerStore(this.file);

  final File file;

  @override
  bool loadPinned() {
    if (!file.existsSync()) return true;
    try {
      final json = jsonDecode(file.readAsStringSync());
      return json is! Map || json['pinned'] != false;
    } on Object {
      return true;
    }
  }

  @override
  void savePinned(bool pinned) {
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(jsonEncode({'pinned': pinned}), flush: true);
    part.renameSync(file.path);
  }
}
