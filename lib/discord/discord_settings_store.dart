import 'dart:convert';
import 'dart:io';

import 'package:studio/discord/discord_settings.dart';

abstract class DiscordSettingsStore {
  DiscordSettings load();
  void save(DiscordSettings settings);
}

class MemoryDiscordSettingsStore implements DiscordSettingsStore {
  MemoryDiscordSettingsStore([this.value = DiscordSettings.defaults]);

  DiscordSettings value;

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

  @override
  DiscordSettings load() {
    if (!file.existsSync()) return DiscordSettings.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return DiscordSettings(enabled: json['enabled'] == true);
    } on Object {
      return DiscordSettings.defaults;
    }
  }

  @override
  void save(DiscordSettings settings) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({'enabled': settings.enabled}));
  }
}
