import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/core/desktop/close_preference_store.dart';

void main() {
  group('MemoryClosePreferenceStore', () {
    test('load returns default preference initially', () {
      final store = MemoryClosePreferenceStore();
      final pref = store.load();
      expect(pref, equals(ClosePreference.defaults));
    });

    test('load returns constructor value if provided', () {
      const initialPref = ClosePreference(
        ask: false,
        remember: CloseAction.quit,
      );
      final store = MemoryClosePreferenceStore(initialPref);
      final pref = store.load();
      expect(pref, equals(initialPref));
    });

    test('save updates the preference', () {
      final store = MemoryClosePreferenceStore();
      const newPref = ClosePreference(ask: false, remember: CloseAction.quit);
      store.save(newPref);
      final pref = store.load();
      expect(pref, equals(newPref));
    });
  });

  group('FileClosePreferenceStore', () {
    late Directory tempDir;
    late File file;
    late FileClosePreferenceStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'close_preference_store_test',
      );
      file = File('${tempDir.path}/prefs.json');
      store = FileClosePreferenceStore(file);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('load returns default when file does not exist', () {
      final pref = store.load();
      expect(pref, equals(ClosePreference.defaults));
    });

    test('save creates file and writes correct JSON', () {
      const pref = ClosePreference(ask: false, remember: CloseAction.quit);
      store.save(pref);

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, equals('{"ask":false,"remember":"quit"}'));
    });

    test('load correctly reads preferences from a valid JSON file', () {
      file.writeAsStringSync('{"ask":false,"remember":"quit"}');
      final pref = store.load();

      expect(pref.ask, isFalse);
      expect(pref.remember, equals(CloseAction.quit));
    });

    test('load handles missing fields gracefully', () {
      file.writeAsStringSync('{}');
      final pref = store.load();

      expect(
        pref.ask,
        isTrue,
      ); // ask defaults to true because json['ask'] != false
      expect(pref.remember, equals(CloseAction.background)); // default Action
    });

    test('load returns default when JSON is corrupted', () {
      file.writeAsStringSync('not json');
      final pref = store.load();

      expect(pref, equals(ClosePreference.defaults));
    });
  });
}
