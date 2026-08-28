import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings.dart';
import 'package:studio/playback/playback_settings_store.dart';

void main() {
  test('mpv values match Off, Track, and Album', () {
    expect(ReplayGainMode.off.mpvValue, 'no');
    expect(ReplayGainMode.track.mpvValue, 'track');
    expect(ReplayGainMode.album.mpvValue, 'album');
  });

  test('unknown names fall back to off', () {
    expect(ReplayGainMode.fromName(null), ReplayGainMode.off);
    expect(ReplayGainMode.fromName('loud'), ReplayGainMode.off);
    expect(ReplayGainMode.fromName('album'), ReplayGainMode.album);
  });

  test('file store round-trips album mode', () {
    final file = File(
      '${Directory.systemTemp.createTempSync('studio-playback').path}/playback.json',
    );
    addTearDown(() {
      if (file.parent.existsSync()) file.parent.deleteSync(recursive: true);
    });
    FilePlaybackSettingsStore(
      file,
    ).save(const PlaybackSettings(replayGain: ReplayGainMode.album));
    expect(
      FilePlaybackSettingsStore(file).load().replayGain,
      ReplayGainMode.album,
    );
  });
}
