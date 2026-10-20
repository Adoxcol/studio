import 'dart:convert';
import 'dart:io';

import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';

abstract class PlaybackSettingsStore {
  PlaybackSettings load();
  Future<PlaybackSettings> loadAsync();
  void save(PlaybackSettings settings);
}

class MemoryPlaybackSettingsStore implements PlaybackSettingsStore {
  MemoryPlaybackSettingsStore([this.value = PlaybackSettings.defaults]);

  PlaybackSettings value;

  @override
  PlaybackSettings load() => value;

  @override
  Future<PlaybackSettings> loadAsync() async => value;

  @override
  void save(PlaybackSettings settings) {
    value = settings;
  }
}

class FilePlaybackSettingsStore implements PlaybackSettingsStore {
  FilePlaybackSettingsStore(this.file);

  final File file;
  PlaybackSettings? _cachedSettings;

  @override
  PlaybackSettings load() {
    if (_cachedSettings != null) return _cachedSettings!;
    if (!file.existsSync()) {
      _cachedSettings = PlaybackSettings.defaults;
      return _cachedSettings!;
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _cachedSettings = _parseJson(json);
      return _cachedSettings!;
    } on Object {
      _cachedSettings = PlaybackSettings.defaults;
      return _cachedSettings!;
    }
  }

  @override
  Future<PlaybackSettings> loadAsync() async {
    if (!await file.exists()) {
      _cachedSettings = PlaybackSettings.defaults;
      return _cachedSettings!;
    }
    try {
      final contents = await file.readAsString();
      final json = jsonDecode(contents) as Map<String, dynamic>;
      _cachedSettings = _parseJson(json);
      return _cachedSettings!;
    } on Object {
      _cachedSettings = PlaybackSettings.defaults;
      return _cachedSettings!;
    }
  }

  PlaybackSettings _parseJson(Map<String, dynamic> json) {
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
  }

  @override
  void save(PlaybackSettings settings) {
    _cachedSettings = settings;
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(
      jsonEncode({
        'replayGain': settings.replayGain.name,
        'equalizerPreset': settings.equalizerPreset.name,
        'equalizerGains': settings.equalizerGains,
        'equalizerPreamp': settings.equalizerPreamp,
        'crossfadeMs': settings.crossfade.inMilliseconds,
      }),
      flush: true,
    );
    part.renameSync(file.path);
  }
}
