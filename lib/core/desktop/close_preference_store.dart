import 'dart:convert';
import 'dart:io';

import 'package:studio/core/desktop/close_preference.dart';

abstract class ClosePreferenceStore {
  ClosePreference load();
  void save(ClosePreference preference);
}

class MemoryClosePreferenceStore implements ClosePreferenceStore {
  MemoryClosePreferenceStore([this.value = ClosePreference.defaults]);

  ClosePreference value;

  @override
  ClosePreference load() => value;

  @override
  void save(ClosePreference preference) {
    value = preference;
  }
}

class FileClosePreferenceStore implements ClosePreferenceStore {
  FileClosePreferenceStore(this.file);

  final File file;

  @override
  ClosePreference load() {
    if (!file.existsSync()) return ClosePreference.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return ClosePreference(
        ask: json['ask'] != false,
        remember: CloseAction.fromName(json['remember'] as String?),
      );
    } on Object {
      return ClosePreference.defaults;
    }
  }

  @override
  void save(ClosePreference preference) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({'ask': preference.ask, 'remember': preference.remember.name}),
    );
  }
}
