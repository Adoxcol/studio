import 'dart:convert';
import 'dart:io';

import 'package:studio/features/scrobbling/domain/scrobble_settings.dart';

abstract class ScrobbleSettingsStore {
  ScrobbleSettings load();
  void save(ScrobbleSettings settings);
}

class MemoryScrobbleSettingsStore implements ScrobbleSettingsStore {
  MemoryScrobbleSettingsStore([this.value = ScrobbleSettings.defaults]);

  ScrobbleSettings value;

  @override
  ScrobbleSettings load() => value;

  @override
  void save(ScrobbleSettings settings) => value = settings;
}

class FileScrobbleSettingsStore implements ScrobbleSettingsStore {
  FileScrobbleSettingsStore(this.file);

  final File file;

  @override
  ScrobbleSettings load() {
    if (!file.existsSync()) return ScrobbleSettings.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync());
      return json is Map<String, dynamic>
          ? ScrobbleSettings.fromJson(json)
          : ScrobbleSettings.defaults;
    } on Object {
      return ScrobbleSettings.defaults;
    }
  }

  @override
  void save(ScrobbleSettings settings) {
    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(jsonEncode(settings.toJson()), flush: true);
    part.renameSync(file.path);
  }
}
