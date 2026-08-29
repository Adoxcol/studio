import 'dart:convert';
import 'dart:io';

import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
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
      final rawGains = json['equalizerGains'];
      final gains = rawGains is List
          ? [
              for (final value in rawGains)
                Equalizer.clampGain((value as num).toDouble()),
            ]
          : Equalizer.flat;
      final ten = gains.length == Equalizer.bandsHz.length;
      return PlaybackSettings(
        replayGain: ReplayGainMode.fromName(json['replayGain'] as String?),
        equalizerPreset: ten
            ? EqualizerPreset.fromName(json['equalizerPreset'] as String?)
            : EqualizerPreset.flat,
        equalizerGains: ten ? gains : Equalizer.flat,
        equalizerPreamp: ten
            ? Equalizer.clampGain(
                (json['equalizerPreamp'] as num?)?.toDouble() ?? 0,
              )
            : 0,
        crossfade: Crossfade.fromMilliseconds(json['crossfadeMs'] as int?),
      );
    } on Object {
      return PlaybackSettings.defaults;
    }
  }

  @override
  void save(PlaybackSettings settings) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({
        'replayGain': settings.replayGain.name,
        'equalizerPreset': settings.equalizerPreset.name,
        'equalizerGains': settings.equalizerGains,
        'equalizerPreamp': settings.equalizerPreamp,
        'crossfadeMs': settings.crossfade.inMilliseconds,
      }),
    );
  }
}
