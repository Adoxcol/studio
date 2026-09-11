import 'dart:convert';
import 'dart:io';

import 'package:studio/features/subsonic/domain/subsonic_models.dart';

abstract class SubsonicSettingsStore {
  SubsonicServerConfig? load();
  void save(SubsonicServerConfig? config);
}

class MemorySubsonicSettingsStore implements SubsonicSettingsStore {
  MemorySubsonicSettingsStore([this.value]);

  SubsonicServerConfig? value;

  @override
  SubsonicServerConfig? load() => value;

  @override
  void save(SubsonicServerConfig? config) {
    value = config;
  }
}

class FileSubsonicSettingsStore implements SubsonicSettingsStore {
  FileSubsonicSettingsStore(this.file);

  final File file;

  @override
  SubsonicServerConfig? load() {
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return SubsonicServerConfig.fromJson(json);
    } on Object {
      return null;
    }
  }

  @override
  void save(SubsonicServerConfig? config) {
    if (config == null) {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(config.toJson()));
  }
}
