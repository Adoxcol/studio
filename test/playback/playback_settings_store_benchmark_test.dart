import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  test('Benchmark FilePlaybackSettingsStore save duration', () async {
    final tempDir = Directory.systemTemp.createTempSync('settings_benchmark_');
    final file = File('${tempDir.path}/playback.json');
    final store = FilePlaybackSettingsStore(file);

    const settings = PlaybackSettings.defaults;

    final sw = Stopwatch()..start();
    const iterations = 100;
    for (var i = 0; i < iterations; i++) {
      await store.save(settings);
    }
    sw.stop();

    expect(sw.elapsedMicroseconds, greaterThan(0));

    tempDir.deleteSync(recursive: true);
  });
}
