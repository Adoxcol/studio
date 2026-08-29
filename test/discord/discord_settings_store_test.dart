import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/discord/discord_settings.dart';
import 'package:studio/discord/discord_settings_store.dart';

void main() {
  test('missing discord.json stays off', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-discord').path}/discord.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    expect(FileDiscordSettingsStore(file).load().enabled, isFalse);
  });

  test('file store round-trips enabled', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-discord').path}/discord.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FileDiscordSettingsStore(file).save(const DiscordSettings(enabled: true));
    expect(FileDiscordSettingsStore(file).load().enabled, isTrue);
  });
}
