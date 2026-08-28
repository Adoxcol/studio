import 'dart:convert';
import 'dart:io';

import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';

abstract class PlaybackSettingsStore {
  PlaybackSettings load();
  void save(PlaybackSettings settings);
}

class MemoryPlaybackSettingsStore implements PlaybackSettingsStore {
  MemoryPlaybackSettingsStore([this.value = PlaybackSettings.defaults]);

  PlaybackSettings value;

  @override
  PlaybackSettings load() => value;

  @override
  void save(PlaybackSettings settings) {
    value = settings;
  }
}

class FilePlaybackSettingsStore implements PlaybackSettingsStore {
  FilePlaybackSettingsStore(this.file);

  final File file;

  @override
  PlaybackSettings load() {
    if (!file.existsSync()) return PlaybackSettings.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return PlaybackSettings(
        replayGain: ReplayGainMode.fromName(json['replayGain'] as String?),
      );
    } on Object {
      return PlaybackSettings.defaults;
    }
  }

  @override
  void save(PlaybackSettings settings) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({'replayGain': settings.replayGain.name}),
    );
  }
}
