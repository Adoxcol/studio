import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

void main() {
  group('MemorySubsonicSettingsStore', () {
    test(
      'initializes with optional default value and allows saving/loading',
      () async {
        final storeEmpty = MemorySubsonicSettingsStore();
        await storeEmpty.init();
        expect(storeEmpty.load(), isNull);

        const config = SubsonicServerConfig(
          serverUrl: 'http://example.com',
          username: 'alice',
          password: 'password123',
          serverName: 'My Server',
        );

        final storeWithVal = MemorySubsonicSettingsStore(config);
        await storeWithVal.init();
        expect(storeWithVal.load(), equals(config));

        storeEmpty.save(config);
        expect(storeEmpty.load(), equals(config));

        storeEmpty.save(null);
        expect(storeEmpty.load(), isNull);
      },
    );
  });

  group('FileSubsonicSettingsStore', () {
    late Directory tempDir;
    late File settingsFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('studio-subsonic-settings');
      settingsFile = File(p.join(tempDir.path, 'subsonic_server.json'));
      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('init with non-existent file produces null config', () async {
      final store = FileSubsonicSettingsStore(settingsFile);
      await store.init();
      expect(store.load(), isNull);
    });

    test(
      'save writes json excluding password and stores password securely',
      () async {
        const storage = FlutterSecureStorage();
        final store = FileSubsonicSettingsStore(settingsFile);

        const config = SubsonicServerConfig(
          serverUrl: 'https://music.example.com',
          username: 'bob',
          password: 'supersecretpassword',
          serverName: 'Bob Server',
        );

        store.save(config);

        // Verify cached config
        expect(store.load(), equals(config));

        // Verify file exists and plaintext file does NOT contain password
        expect(settingsFile.existsSync(), isTrue);
        final fileContent = settingsFile.readAsStringSync();
        final decodedJson = jsonDecode(fileContent) as Map<String, dynamic>;
        expect(decodedJson.containsKey('password'), isFalse);
        expect(decodedJson['serverUrl'], 'https://music.example.com');
        expect(decodedJson['username'], 'bob');
        expect(decodedJson['serverName'], 'Bob Server');

        // Verify secure storage contains password
        final securePassword = await storage.read(key: 'subsonic_password');
        expect(securePassword, 'supersecretpassword');

        // Re-initialize a new store instance from file and secure storage
        final store2 = FileSubsonicSettingsStore(settingsFile);
        await store2.init();
        final loaded = store2.load();
        expect(loaded, isNotNull);
        expect(loaded!.serverUrl, 'https://music.example.com');
        expect(loaded.username, 'bob');
        expect(loaded.serverName, 'Bob Server');
        expect(loaded.password, 'supersecretpassword');
      },
    );

    test(
      'save with null deletes file and removes password from secure storage',
      () async {
        const storage = FlutterSecureStorage();
        final store = FileSubsonicSettingsStore(settingsFile);

        const config = SubsonicServerConfig(
          serverUrl: 'https://music.example.com',
          username: 'bob',
          password: 'supersecretpassword',
        );

        store.save(config);
        expect(settingsFile.existsSync(), isTrue);

        store.save(null);
        expect(store.load(), isNull);
        expect(settingsFile.existsSync(), isFalse);

        final securePassword = await storage.read(key: 'subsonic_password');
        expect(securePassword, isNull);
      },
    );

    test('init migrates legacy plaintext password to secure storage', () async {
      const storage = FlutterSecureStorage();

      // Simulate legacy settings file with plaintext password
      final legacyData = {
        'serverUrl': 'http://legacy.subsonic.org',
        'username': 'legacy_user',
        'password': 'plain_password',
        'serverName': 'Legacy Subsonic',
      };
      settingsFile.parent.createSync(recursive: true);
      settingsFile.writeAsStringSync(jsonEncode(legacyData));

      final store = FileSubsonicSettingsStore(settingsFile);
      await store.init();

      // Check config loaded
      final loaded = store.load();
      expect(loaded, isNotNull);
      expect(loaded!.username, 'legacy_user');
      expect(loaded.password, 'plain_password');

      // Plaintext file should have been scrubbed of password
      final rewrittenJson =
          jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
      expect(rewrittenJson.containsKey('password'), isFalse);
      expect(rewrittenJson['username'], 'legacy_user');

      // Secure storage should now hold migrated password
      final securePassword = await storage.read(key: 'subsonic_password');
      expect(securePassword, 'plain_password');
    });

    test('init handles corrupted file gracefully', () async {
      settingsFile.parent.createSync(recursive: true);
      settingsFile.writeAsStringSync('{corrupted json content');

      final store = FileSubsonicSettingsStore(settingsFile);
      await store.init();
      expect(store.load(), isNull);
    });

    test('init handles non-map json gracefully', () async {
      settingsFile.parent.createSync(recursive: true);
      settingsFile.writeAsStringSync('["a", "b", "c"]');

      final store = FileSubsonicSettingsStore(settingsFile);
      await store.init();
      expect(store.load(), isNull);
    });
  });
}
