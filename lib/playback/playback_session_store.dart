import 'dart:convert';
import 'dart:io';

import 'package:studio/playback/playback_session.dart';

abstract class PlaybackSessionStore {
  PlaybackSession load();
  void save(PlaybackSession session);
}

class MemoryPlaybackSessionStore implements PlaybackSessionStore {
  MemoryPlaybackSessionStore([this.value = PlaybackSession.empty]);

  PlaybackSession value;

  @override
  PlaybackSession load() => value;

  @override
  void save(PlaybackSession session) {
    value = session;
  }
}

class FilePlaybackSessionStore implements PlaybackSessionStore {
  FilePlaybackSessionStore(this.file);

  final File file;

  @override
  PlaybackSession load() {
    if (!file.existsSync()) return PlaybackSession.empty;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return PlaybackSession.empty;
      return PlaybackSession.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      return PlaybackSession.empty;
    }
  }

  @override
  void save(PlaybackSession session) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(session.toJson()));
  }
}
