import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late ScrobbleSettings _cachedSettings;

  Future<void> init() async {
    _cachedSettings = ScrobbleSettings.defaults;
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
      _cachedSettings = ScrobbleSettings.fromJson(json);

      // Migration: if secrets were stored in the plaintext file, move them to secure storage.
      bool needsMigration = false;
      if (json['lastFmSecret'] is String &&
          (json['lastFmSecret'] as String).isNotEmpty) {
        await _secureStorage.write(
          key: 'scrobbling_lastFmSecret',
          value: json['lastFmSecret'] as String,
        );
        needsMigration = true;
      }
      if (json['lastFmSessionKey'] is String &&
          (json['lastFmSessionKey'] as String).isNotEmpty) {
        await _secureStorage.write(
          key: 'scrobbling_lastFmSessionKey',
          value: json['lastFmSessionKey'] as String,
        );
        needsMigration = true;
      }
      if (json['listenBrainzToken'] is String &&
          (json['listenBrainzToken'] as String).isNotEmpty) {
        await _secureStorage.write(
          key: 'scrobbling_listenBrainzToken',
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
    final lastFmSecret = await _secureStorage.read(
      key: 'scrobbling_lastFmSecret',
    );
    final lastFmSessionKey = await _secureStorage.read(
      key: 'scrobbling_lastFmSessionKey',
    );
    final listenBrainzToken = await _secureStorage.read(
      key: 'scrobbling_listenBrainzToken',
    );

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
  }

  @override
  ScrobbleSettings load() => _cachedSettings;

  @override
  void save(ScrobbleSettings settings) {
    _cachedSettings = settings;

    // Save secrets to secure storage asynchronously
    // Catch errors on these unawaited Futures to prevent app crashes on failure
    _secureStorage.write(
      key: 'scrobbling_lastFmSecret',
      value: settings.lastFmSecret,
    ).catchError((_) {});
    _secureStorage.write(
      key: 'scrobbling_lastFmSessionKey',
      value: settings.lastFmSessionKey,
    ).catchError((_) {});
    _secureStorage.write(
      key: 'scrobbling_listenBrainzToken',
      value: settings.listenBrainzToken,
    ).catchError((_) {});

    _writeSync(settings);
  }

  void _writeSync(ScrobbleSettings settings) {
    final json = settings.toJson();
    // Exclude secrets from plaintext JSON
    json.remove('lastFmSecret');
    json.remove('lastFmSessionKey');
    json.remove('listenBrainzToken');

    file.parent.createSync(recursive: true);
    final part = File('${file.path}.part');
    part.writeAsStringSync(jsonEncode(json), flush: true);
    part.renameSync(file.path);
  }
}
