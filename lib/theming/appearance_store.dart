import 'dart:convert';
import 'dart:io';

import 'package:studio/theming/accent_seed.dart';

abstract class AppearanceStore {
  AppearanceState load();
  void save(AppearanceState state);
}

class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.value = AppearanceState.defaults]);

  AppearanceState value;

  @override
  AppearanceState load() => value;

  @override
  void save(AppearanceState state) {
    value = state;
  }
}

class FileAppearanceStore implements AppearanceStore {
  FileAppearanceStore(this.file);

  final File file;

  @override
  AppearanceState load() {
    if (!file.existsSync()) return AppearanceState.defaults;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final modeName = json['mode'] as String?;
      final hue = (json['customHue'] as num?)?.toDouble();
      return AppearanceState(
        mode: modeName == 'custom' ? AccentMode.custom : AccentMode.auto,
        customHue: hue ?? AccentSeed.defaultHue,
      );
    } on Object {
      return AppearanceState.defaults;
    }
  }

  @override
  void save(AppearanceState state) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      jsonEncode({'mode': state.mode.name, 'customHue': state.customHue}),
    );
  }
}
