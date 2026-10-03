import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studio/features/scrobbling/domain/scrobble_settings.dart';

abstract class ScrobbleSettingsStore {
  Future<ScrobbleSettings> load();
  Future<void> save(ScrobbleSettings settings);
}

class MemoryScrobbleSettingsStore implements ScrobbleSettingsStore {
  MemoryScrobbleSettingsStore([this.value = ScrobbleSettings.defaults]);

  ScrobbleSettings value;

  @override
  Future<ScrobbleSettings> load() async => value;

  @override
  Future<void> save(ScrobbleSettings settings) async => value = settings;
}

class SecureScrobbleSettingsStore implements ScrobbleSettingsStore {
  SecureScrobbleSettingsStore({
    required this.legacyFile,
    this.storage = const FlutterSecureStorage(),
  });

  final File legacyFile;
  final FlutterSecureStorage storage;
  static const _key = 'scrobble_settings';

  @override
  Future<ScrobbleSettings> load() async {
    try {
      final value = await storage.read(key: _key);
      if (value != null) {
        final json = jsonDecode(value);
        return json is Map<String, dynamic>
            ? ScrobbleSettings.fromJson(json)
            : ScrobbleSettings.defaults;
      }
    } on Object {
      // Ignore secure storage errors, fallback to defaults or legacy
    }

    if (!legacyFile.existsSync()) return ScrobbleSettings.defaults;

    try {
      final json = jsonDecode(legacyFile.readAsStringSync());
      final settings = json is Map<String, dynamic>
          ? ScrobbleSettings.fromJson(json)
          : ScrobbleSettings.defaults;

      // Migrate to secure storage and delete legacy file
      await save(settings);
      legacyFile.deleteSync();
      return settings;
    } on Object {
      return ScrobbleSettings.defaults;
    }
  }

  @override
  Future<void> save(ScrobbleSettings settings) async {
    await storage.write(key: _key, value: jsonEncode(settings.toJson()));
  }
}
