import 'dart:convert';
import 'dart:io';

import 'package:studio/discord/discord_settings.dart';

abstract class DiscordSettingsStore {
  Future<DiscordSettings> loadAsync() async => load();
  DiscordSettings load();
  void save(DiscordSettings settings);
}

class MemoryDiscordSettingsStore implements DiscordSettingsStore {
  MemoryDiscordSettingsStore([this.value = DiscordSettings.defaults]);

  DiscordSettings value;

  @override
  Future<DiscordSettings> loadAsync() async => value;

  @override
  DiscordSettings load() => value;

  @override
  void save(DiscordSettings settings) {
    value = settings;
  }
}

class FileDiscordSettingsStore implements DiscordSettingsStore {
  FileDiscordSettingsStore(this.file);

  final File file;
  DiscordSettings? _cache;
  Future<DiscordSettings>? _loading;

  @override
  Future<DiscordSettings> loadAsync() async {
    if (_cache != null) return _cache!;
    if (_loading != null) return _loading!;

    return _loading = Future(() async {
      if (!await file.exists()) return _cache = DiscordSettings.defaults;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return _cache = DiscordSettings(
          enabled: json['enabled'] == true,
          nameTemplate:
              json['nameTemplate'] as String? ??
              DiscordSettings.defaultNameTemplate,
          detailsTemplate:
              json['detailsTemplate'] as String? ??
              DiscordSettings.defaultDetailsTemplate,
          stateTemplate:
              json['stateTemplate'] as String? ??
              DiscordSettings.defaultStateTemplate,
          artworkTextTemplate:
              json['artworkTextTemplate'] as String? ??
              DiscordSettings.defaultArtworkTextTemplate,
          showProgress: json['showProgress'] != false,
        );
      } on Object {
        return _cache = DiscordSettings.defaults;
      }
    });
  }

  @override
  DiscordSettings load() {
    if (_cache != null) return _cache!;
    if (!file.existsSync()) return _cache = DiscordSettings.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return _cache = DiscordSettings(
        enabled: json['enabled'] == true,
        nameTemplate:
            json['nameTemplate'] as String? ??
            DiscordSettings.defaultNameTemplate,
        detailsTemplate:
            json['detailsTemplate'] as String? ??
            DiscordSettings.defaultDetailsTemplate,
        stateTemplate:
            json['stateTemplate'] as String? ??
            DiscordSettings.defaultStateTemplate,
        artworkTextTemplate:
            json['artworkTextTemplate'] as String? ??
            DiscordSettings.defaultArtworkTextTemplate,
        showProgress: json['showProgress'] != false,
      );
    } on Object {
      return _cache = DiscordSettings.defaults;
    }
  }

  @override
  void save(DiscordSettings settings) {
    _cache = settings;
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(
      jsonEncode({
        'enabled': settings.enabled,
        'nameTemplate': settings.nameTemplate,
        'detailsTemplate': settings.detailsTemplate,
        'stateTemplate': settings.stateTemplate,
        'artworkTextTemplate': settings.artworkTextTemplate,
        'showProgress': settings.showProgress,
      }),
      flush: true,
    );
    part.renameSync(file.path);
  }
}
