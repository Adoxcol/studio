import 'dart:convert';
import 'dart:io';

import 'package:studio/playback/playback_session.dart';

abstract class PlaybackSessionStore {
  Future<PlaybackSession> load();
  void save(PlaybackSession session);
}

class MemoryPlaybackSessionStore implements PlaybackSessionStore {
  MemoryPlaybackSessionStore([this.value = PlaybackSession.empty]);

  PlaybackSession value;

  @override
  Future<PlaybackSession> load() async => value;

  @override
  void save(PlaybackSession session) {
    value = session;
  }
}

class FilePlaybackSessionStore implements PlaybackSessionStore {
  FilePlaybackSessionStore(this.file);

  final File file;

  @override
  Future<PlaybackSession> load() async {
    if (!await file.exists()) return PlaybackSession.empty;
    try {
      final decoded = jsonDecode(await file.readAsString());
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
