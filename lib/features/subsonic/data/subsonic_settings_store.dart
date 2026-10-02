import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

class SecureSubsonicSettingsStore implements SubsonicSettingsStore {
  SecureSubsonicSettingsStore(this.legacyFile, this.secureStorage);

  final File legacyFile;
  final FlutterSecureStorage secureStorage;

  SubsonicServerConfig? _cachedConfig;
  static const _secureKey = 'subsonic_config';

  Future<void> init() async {
    final secureData = await secureStorage.read(key: _secureKey);
    if (secureData != null) {
      try {
        final json = jsonDecode(secureData) as Map<String, dynamic>;
        _cachedConfig = SubsonicServerConfig.fromJson(json);
        return;
      } on Object {
        // Fall back if decoding fails
      }
    }

    // Migration from plaintext to secure storage
    if (legacyFile.existsSync()) {
      try {
        final json =
            jsonDecode(legacyFile.readAsStringSync()) as Map<String, dynamic>;
        _cachedConfig = SubsonicServerConfig.fromJson(json);

        // Save to secure storage and delete legacy file
        await secureStorage.write(
          key: _secureKey,
          value: jsonEncode(_cachedConfig!.toJson()),
        );
        legacyFile.deleteSync();
      } on Object {
        // Do nothing if migration fails
      }
    }
  }

  @override
  SubsonicServerConfig? load() => _cachedConfig;

  @override
  void save(SubsonicServerConfig? config) {
    _cachedConfig = config;
    if (config == null) {
      secureStorage.delete(key: _secureKey);
      if (legacyFile.existsSync()) {
        legacyFile.deleteSync();
      }
      return;
    }
    secureStorage.write(key: _secureKey, value: jsonEncode(config.toJson()));
  }
}
