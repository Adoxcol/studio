import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

void main() {
  group('SecureSubsonicSettingsStore', () {
    late Directory tempDir;
    late File legacyFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('subsonic_store_test');
      legacyFile = File('${tempDir.path}/subsonic.json');

      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('migrates legacy file to secure storage', () async {
      final config = SubsonicServerConfig(
        serverUrl: 'http://example.com',
        username: 'user',
        password: 'password',
      );

      legacyFile.writeAsStringSync(jsonEncode(config.toJson()));
      expect(legacyFile.existsSync(), true);

      final secureStorage = FlutterSecureStorage();
      final store = SecureSubsonicSettingsStore(legacyFile, secureStorage);

      await store.init();

      // Migration should delete legacy file
      expect(legacyFile.existsSync(), false);

      final loaded = store.load();
      expect(loaded, isNotNull);
      expect(loaded?.serverUrl, 'http://example.com');

      // Should be saved in secure storage
      final storedData = await secureStorage.read(key: 'subsonic_config');
      expect(storedData, isNotNull);
    });

    test('loads from secure storage if available', () async {
      final secureStorage = FlutterSecureStorage();
      final config = SubsonicServerConfig(
        serverUrl: 'http://example.com/secure',
        username: 'secure_user',
        password: 'secure_password',
      );

      await secureStorage.write(key: 'subsonic_config', value: jsonEncode(config.toJson()));

      final store = SecureSubsonicSettingsStore(legacyFile, secureStorage);
      await store.init();

      final loaded = store.load();
      expect(loaded?.serverUrl, 'http://example.com/secure');
    });

    test('save updates memory and secure storage', () async {
      final secureStorage = FlutterSecureStorage();
      final store = SecureSubsonicSettingsStore(legacyFile, secureStorage);
      await store.init();

      final config = SubsonicServerConfig(
        serverUrl: 'http://save.com',
        username: 'u',
        password: 'p',
      );

      store.save(config);
      expect(store.load()?.serverUrl, 'http://save.com');

      // Should eventually update secure storage, wait a bit
      await Future.delayed(Duration(milliseconds: 100));
      final storedData = await secureStorage.read(key: 'subsonic_config');
      expect(storedData, isNotNull);
    });

    test('save null clears everything', () async {
      legacyFile.writeAsStringSync('{}');
      final secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'subsonic_config', value: '{}');

      final store = SecureSubsonicSettingsStore(legacyFile, secureStorage);
      await store.init();

      store.save(null);

      expect(store.load(), isNull);
      expect(legacyFile.existsSync(), false);

      await Future.delayed(Duration(milliseconds: 100));
      expect(await secureStorage.read(key: 'subsonic_config'), isNull);
    });
  });
}
