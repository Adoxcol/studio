import 'dart:convert';
import 'dart:io';

import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';

abstract class PlaybackSettingsStore {
  PlaybackSettings load();
  Future<void> save(PlaybackSettings settings);
  Future<PlaybackSettings> loadAsync() async => load();
  void save(PlaybackSettings settings);
}

class MemoryPlaybackSettingsStore implements PlaybackSettingsStore {
  MemoryPlaybackSettingsStore([this.value = PlaybackSettings.defaults]);

  PlaybackSettings value;

  @override
  PlaybackSettings load() => value;

  @override
  Future<void> save(PlaybackSettings settings) async {
  Future<PlaybackSettings> loadAsync() async => value;

  @override
  void save(PlaybackSettings settings) {
    value = settings;
  }
}

class FilePlaybackSettingsStore implements PlaybackSettingsStore {
  FilePlaybackSettingsStore(this.file);

  final File file;
  Future<void> _lastSave = Future.value();
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
    if (_cachedSettings != null) return _cachedSettings!;
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
  Future<void> save(PlaybackSettings settings) {
    final next = _lastSave.then((_) async {
      try {
        await file.parent.create(recursive: true);
        final part = File('${file.path}.part');
        await part.writeAsString(
          jsonEncode({
            'replayGain': settings.replayGain.name,
            'equalizerPreset': settings.equalizerPreset.name,
            'equalizerGains': settings.equalizerGains,
            'equalizerPreamp': settings.equalizerPreamp,
            'crossfadeMs': settings.crossfade.inMilliseconds,
          }),
          flush: true,
        );
        await part.rename(file.path);
      } on Object {
        // Ignore write errors to match non-blocking store contract.
      }
    });
    _lastSave = next.catchError((_) {});
    return next;
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
