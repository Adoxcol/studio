import 'dart:convert';
import 'dart:io';

import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';

/// Opt-in local setup: credentials arrive over stdin, never as command-line
/// arguments. Uses the same atomic settings writer as Studio's settings panel.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/configure_fanart.dart <fanart.json path>',
    );
    exitCode = 64;
    return;
  }
  try {
    final line = await stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final json = jsonDecode(line) as Map;
    final project = (json['projectKey'] as String? ?? '').trim();
    final personal = (json['personalKey'] as String? ?? '').trim();
    if ([project, personal].any(
      (key) =>
          key.isNotEmpty && !RegExp(r'^[a-fA-F0-9]{16,128}$').hasMatch(key),
    )) {
      throw const FormatException('Invalid key format');
    }
    final store = FanartSettingsStore(file: File(args.single));
    await store.save(
      FanartSettings(
        projectKey: project,
        personalKey: personal,
        revision: store.load().revision + 1,
      ),
    );
    stdout.writeln(
      'Fanart keys saved in local app settings (unencrypted). No credentials logged.',
    );
  } on Object {
    stderr.writeln(
      'Could not save fanart settings. Check the input and destination permissions.',
    );
    exitCode = 1;
  }
}
