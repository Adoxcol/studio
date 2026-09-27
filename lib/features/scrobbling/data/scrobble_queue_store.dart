import 'dart:convert';
import 'dart:io';

import 'package:studio/features/scrobbling/domain/scrobble_track.dart';

/// Pending scrobbles per service id, kept across restarts and outages.
abstract class ScrobbleQueueStore {
  Map<String, List<ScrobbleTrack>> load();
  void save(Map<String, List<ScrobbleTrack>> queues);
}

class MemoryScrobbleQueueStore implements ScrobbleQueueStore {
  Map<String, List<ScrobbleTrack>> value = {};

  @override
  Map<String, List<ScrobbleTrack>> load() => {
    for (final entry in value.entries) entry.key: [...entry.value],
  };

  @override
  void save(Map<String, List<ScrobbleTrack>> queues) {
    value = {
      for (final entry in queues.entries) entry.key: [...entry.value],
    };
  }
}

class FileScrobbleQueueStore implements ScrobbleQueueStore {
  FileScrobbleQueueStore(this.file);

  final File file;

  @override
  Map<String, List<ScrobbleTrack>> load() {
    if (!file.existsSync()) return {};
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map) return {};
      return {
        for (final entry in json.entries)
          if (entry.value is List)
            '${entry.key}': [
              for (final item in entry.value as List)
                ?ScrobbleTrack.fromJson(item),
            ],
      };
    } on Object {
      return {};
    }
  }

  @override
  void save(Map<String, List<ScrobbleTrack>> queues) {
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(
      jsonEncode({
        for (final entry in queues.entries)
          if (entry.value.isNotEmpty)
            entry.key: [for (final track in entry.value) track.toJson()],
      }),
      flush: true,
    );
    part.renameSync(file.path);
  }
}
