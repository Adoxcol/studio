import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

abstract class SubsonicSettingsStore {
  Future<void> init();
  SubsonicServerConfig? load();
  void save(SubsonicServerConfig? config);
}

class MemorySubsonicSettingsStore implements SubsonicSettingsStore {
  MemorySubsonicSettingsStore([this.value]);

  SubsonicServerConfig? value;

  @override
  Future<void> init() async {}

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SubsonicServerConfig? _cachedConfig;

  @override
  Future<void> init() async {
    Map<String, dynamic>? json;
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } on Object {
        // Ignored
      }
    }

    if (json != null) {
      try {
        _cachedConfig = SubsonicServerConfig.fromJson(json);

        // Migration: if password was stored in the plaintext file, move it to secure storage.
        bool needsMigration = false;
        if (json['password'] is String &&
            (json['password'] as String).isNotEmpty) {
          try {
            await _secureStorage.write(
              key: 'subsonic_password',
              value: json['password'] as String,
            );
            needsMigration = true;
          } on Object {
            // Secure storage unavailable, do not migrate and clear it
          }
        }

        if (needsMigration) {
          // Save without password to clear the plaintext file
          _writeSync(_cachedConfig!);
        }
      } on Object {
        // Corrupted JSON format
        _cachedConfig = null;
      }
    }

    if (_cachedConfig != null) {
      // Now overlay any values from secure storage over the loaded config
      String? password;
      try {
        password = await _secureStorage.read(key: 'subsonic_password');
      } on Object {
        // Secure storage unavailable
      }

      if (password != null) {
        _cachedConfig = _cachedConfig!.copyWith(password: password);
      }
    }
  }

  @override
  SubsonicServerConfig? load() => _cachedConfig;

  @override
  void save(SubsonicServerConfig? config) {
    _cachedConfig = config;

    if (config == null) {
      _secureStorage
          .delete(key: 'subsonic_password')
          .catchError((_) {}); // Secure storage unavailable
      if (file.existsSync()) {
        file.deleteSync();
      }
      return;
    }

    // Save password to secure storage asynchronously
    _secureStorage
        .write(key: 'subsonic_password', value: config.password)
        .catchError((_) {}); // Secure storage unavailable

    _writeSync(config);
  }

  void _writeSync(SubsonicServerConfig config) {
    final json = config.toJson();
    // Exclude password from plaintext JSON
    json.remove('password');

    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(jsonEncode(json), flush: true);
    part.renameSync(file.path);
  }
}
