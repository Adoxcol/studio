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
  late ScrobbleSettings _cachedSettings;
  bool _initialized = false;

  static const _lastFmSecretKey = 'scrobbling_lastFmSecret';
  static const _lastFmSessionKeyKey = 'scrobbling_lastFmSessionKey';
  static const _listenBrainzTokenKey = 'scrobbling_listenBrainzToken';

  Future<void> init() async {
    if (_initialized) return;

    _cachedSettings = ScrobbleSettings.defaults;
    Map<String, dynamic>? json;
    if (legacyFile.existsSync()) {
      try {
        final decoded = jsonDecode(legacyFile.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } on Object {
        // Ignored
      }
    }

    if (json != null) {
      _cachedSettings = ScrobbleSettings.fromJson(json);

      // Migration: if secrets were stored in the plaintext file, move them to secure storage.
      bool needsMigration = false;
      if (json['lastFmSecret'] is String &&
          (json['lastFmSecret'] as String).isNotEmpty) {
        await storage.write(
          key: _lastFmSecretKey,
          value: json['lastFmSecret'] as String,
        );
        needsMigration = true;
      }
      if (json['lastFmSessionKey'] is String &&
          (json['lastFmSessionKey'] as String).isNotEmpty) {
        await storage.write(
          key: _lastFmSessionKeyKey,
          value: json['lastFmSessionKey'] as String,
        );
        needsMigration = true;
      }
      if (json['listenBrainzToken'] is String &&
          (json['listenBrainzToken'] as String).isNotEmpty) {
        await storage.write(
          key: _listenBrainzTokenKey,
          value: json['listenBrainzToken'] as String,
        );
        needsMigration = true;
      }

      if (needsMigration) {
        // Save without secrets to clear the plaintext file
        _writeSync(_cachedSettings);
      }
    }

    // Now overlay any values from secure storage over the loaded settings
    final lastFmSecret = await storage.read(key: _lastFmSecretKey);
    final lastFmSessionKey = await storage.read(key: _lastFmSessionKeyKey);
    final listenBrainzToken = await storage.read(key: _listenBrainzTokenKey);

    if (lastFmSecret != null ||
        lastFmSessionKey != null ||
        listenBrainzToken != null) {
      _cachedSettings = _cachedSettings.copyWith(
        lastFmSecret: lastFmSecret ?? _cachedSettings.lastFmSecret,
        lastFmSessionKey: lastFmSessionKey ?? _cachedSettings.lastFmSessionKey,
        listenBrainzToken:
            listenBrainzToken ?? _cachedSettings.listenBrainzToken,
      );
    }

    _initialized = true;
  }

  @override
  Future<ScrobbleSettings> load() async {
    await init();
    return _cachedSettings;
  }

  @override
  Future<void> save(ScrobbleSettings settings) async {
    await init();
    _cachedSettings = settings;

    await storage.write(key: _lastFmSecretKey, value: settings.lastFmSecret);
    await storage.write(
      key: _lastFmSessionKeyKey,
      value: settings.lastFmSessionKey,
    );
    await storage.write(
      key: _listenBrainzTokenKey,
      value: settings.listenBrainzToken,
    );

    _writeSync(settings);
  }

  void _writeSync(ScrobbleSettings settings) {
    final json = settings.toJson();
    // Exclude secrets from plaintext JSON
    json.remove('lastFmSecret');
    json.remove('lastFmSessionKey');
    json.remove('listenBrainzToken');

    legacyFile.parent.createSync(recursive: true);
    final part = File('${legacyFile.path}.part');
    part.writeAsStringSync(jsonEncode(json), flush: true);
    part.renameSync(legacyFile.path);
  }
}
