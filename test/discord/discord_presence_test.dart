import 'package:flutter_test/flutter_test.dart';
import 'package:studio/discord/discord_ids.dart';
import 'package:studio/discord/discord_presence.dart';
import 'package:studio/discord/discord_settings.dart';
import 'package:studio/state/playback_provider.dart';

void main() {
  final now = DateTime.utc(2026, 8, 29, 4, 0, 0);

  test('idle playback clears Discord', () {
    expect(discordPresenceFor(const PlaybackUiState(), now: now), isNull);
  });

  test('playing track is a Listening card with a progress bar', () {
    final view = discordPresenceFor(
      const PlaybackUiState(
        trackId: 1,
        title: 'MONSTER',
        artist: 'Shawn Mendes, Justin Bieber',
        album: 'Wonder',
        playing: true,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 3, seconds: 55),
      ),
      now: now,
    );
    expect(view, isNotNull);
    expect(view!.details, 'MONSTER');
    expect(view.state, 'Shawn Mendes, Justin Bieber');
    expect(view.album, 'Wonder');
    expect(view.name, 'Shawn Mendes, Justin Bieber - MONSTER');
    expect(view.largeImage, kDiscordLargeImageKey);
    expect(view.playing, isTrue);
    expect(view.buttonLabel, 'Play');
    expect(view.smallImageKey, kDiscordPlayImageKey);
    expect(view.start, now.subtract(const Duration(seconds: 30)));
    expect(view.end, now.add(const Duration(minutes: 3, seconds: 25)));
    expect(view.timestampsPayload, {
      'start': view.start!.millisecondsSinceEpoch ~/ 1000,
      'end': view.end!.millisecondsSinceEpoch ~/ 1000,
    });
    expect(
      view.timestampsPayload!['end']! - view.timestampsPayload!['start']!,
      235,
    );
  });

  test('paused track shows Pause and drops timestamps', () {
    final view = discordPresenceFor(
      const PlaybackUiState(
        trackId: 1,
        title: 'MONSTER',
        artist: 'Shawn Mendes, Justin Bieber',
        album: 'Wonder',
        playing: false,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 3, seconds: 55),
      ),
      now: now,
    );
    expect(view!.details, 'MONSTER');
    expect(view.state, 'Shawn Mendes, Justin Bieber');
    expect(view.album, 'Wonder');
    expect(view.playing, isFalse);
    expect(view.buttonLabel, 'Pause');
    expect(view.smallImageKey, kDiscordPauseImageKey);
    expect(view.start, isNull);
    expect(view.end, isNull);
    expect(view.timestampsPayload, isNull);
  });

  test('clips titles to Discord\'s 128-character cap', () {
    final view = discordPresenceFor(
      PlaybackUiState(trackId: 1, title: 'x' * 200, playing: true),
      now: now,
    );
    expect(view!.details.length, 128);
    expect(view.name.length, 128);
  });

  test('HTTPS cover URL stays raw for Discord to proxy', () {
    final view = discordPresenceFor(
      const PlaybackUiState(trackId: 1, title: 'Headlines', playing: true),
      now: now,
      largeImage: 'https://iili.io/cover.jpg',
    );
    expect(view!.largeImage, 'https://iili.io/cover.jpg');
  });

  test('compact name is the track when artist is missing', () {
    final view = discordPresenceFor(
      const PlaybackUiState(trackId: 1, title: 'Untitled', playing: true),
      now: now,
    );
    expect(view!.state, isNull);
    expect(view.album, isNull);
    expect(view.name, 'Untitled');
  });

  test('custom templates can showcase audio quality', () {
    final view = discordPresenceFor(
      const PlaybackUiState(
        trackId: 1,
        title: 'So What',
        artist: 'Miles Davis',
        locator: '/music/so-what.flac',
        fileSizeBytes: 33000000,
        sampleRateHz: 96000,
        duration: Duration(minutes: 9, seconds: 22),
        playing: true,
      ),
      now: now,
      settings: const DiscordSettings(
        stateTemplate: '{artist}[ • {quality}]',
        showProgress: false,
      ),
    );
    expect(view!.state, 'Miles Davis • FLAC • Lossless • 470 kbps • 96 kHz');
    expect(view.start, isNull);
    expect(view.end, isNull);
  });
}
