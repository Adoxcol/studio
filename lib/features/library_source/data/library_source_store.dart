import 'dart:convert';
import 'dart:io';

/// Where the Library page reads its catalogue from. Kept apart from folders:
/// a source is a whole catalogue (this computer, a Navidrome server), a
/// folder is a place inside one.
enum LibrarySource {
  local('This computer'),
  navidrome('Navidrome');

  const LibrarySource(this.label);
  final String label;
}

/// Remembers the Library source across tabs and launches.
abstract class LibrarySourceStore {
  /// Null until the user has picked a source.
  LibrarySource? load();
  void save(LibrarySource source);
}

class MemoryLibrarySourceStore implements LibrarySourceStore {
  MemoryLibrarySourceStore([this.source]);

  LibrarySource? source;

  @override
  LibrarySource? load() => source;

  @override
  void save(LibrarySource value) => source = value;
}

class FileLibrarySourceStore implements LibrarySourceStore {
  FileLibrarySourceStore(this.file);

  final File file;

  @override
  LibrarySource? load() {
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync());
      final name = json is Map ? json['source'] : null;
      return LibrarySource.values.where((s) => s.name == name).firstOrNull;
    } on Object {
      return null;
    }
  }

  @override
  void save(LibrarySource source) {
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(jsonEncode({'source': source.name}), flush: true);
    part.renameSync(file.path);
  }
}
