import 'dart:convert';
import 'dart:io';

class FanartSettings {
  const FanartSettings({
    this.projectKey = '',
    this.personalKey = '',
    this.revision = 0,
  });
  final String projectKey;
  final String personalKey;
  final int revision;
  bool get enabled => projectKey.isNotEmpty || personalKey.isNotEmpty;
  Map<String, String> get headers => {
    if (projectKey.isNotEmpty) 'api-key': projectKey,
    if (personalKey.isNotEmpty) 'client-key': personalKey,
  };

  // Never expose credentials through diagnostics / provider inspection.
  @override
  String toString() => 'FanartSettings(enabled: $enabled)';
}

/// Local app-support settings, not a bundled secret or a repository file.
/// Deliberately explicit in the UI that this is not encrypted storage.
class FanartSettingsStore {
  FanartSettingsStore({this.file});
  final File? file;
  FanartSettings _memory = const FanartSettings();

  FanartSettings load() {
    if (file == null || !file!.existsSync()) return _memory;
    try {
      final json = jsonDecode(file!.readAsStringSync()) as Map;
      return _memory = FanartSettings(
        projectKey: json['projectKey'] as String? ?? '',
        personalKey: json['personalKey'] as String? ?? '',
        revision: json['revision'] as int? ?? 0,
      );
    } on FormatException {
      return _memory;
    } on TypeError {
      return _memory;
    }
  }

  Future<void> save(FanartSettings settings) async {
    if (file != null) {
      await file!.parent.create(recursive: true);
      final part = File('${file!.path}.part');
      await part.writeAsString(
        jsonEncode({
          'projectKey': settings.projectKey,
          'personalKey': settings.personalKey,
          'revision': settings.revision,
        }),
        flush: true,
      );
      await part.rename(file!.path);
    }
    _memory = settings;
  }
}
