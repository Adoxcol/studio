import 'package:flutter_test/flutter_test.dart';
import 'package:studio/discord/discord_template.dart';
import 'package:studio/state/playback_provider.dart';

void main() {
  const lossless = PlaybackUiState(
    trackId: 1,
    title: 'So What',
    artist: 'Miles Davis',
    album: 'Kind of Blue',
    genre: 'Jazz',
    year: 1959,
    locator: '/music/So What.flac',
    fileSizeBytes: 33000000,
    sampleRateHz: 96000,
    duration: Duration(minutes: 9, seconds: 22),
    playing: true,
  );

  test('renders file and lossless quality variables', () {
    expect(
      renderDiscordTemplate('{artist}[ • {quality}]', lossless),
      'Miles Davis • FLAC • Lossless • 470 kbps • 96 kHz',
    );
    expect(renderDiscordTemplate('{filename}', lossless), 'So What.flac');
    expect(renderDiscordTemplate('{file_stem}', lossless), 'So What');
  });

  test('optional groups disappear with unavailable metadata', () {
    const track = PlaybackUiState(trackId: 1, title: 'Untitled');
    expect(renderDiscordTemplate('[{artist} - ]{title}', track), 'Untitled');
    expect(renderDiscordTemplate('{title}[ • {quality}]', track), 'Untitled');
  });

  test('formats common sample rates without noisy decimals', () {
    expect(discordTemplateValues(lossless)['sample_rate'], '96 kHz');
    expect(
      discordTemplateValues(
        const PlaybackUiState(sampleRateHz: 44100),
      )['sample_rate'],
      '44.1 kHz',
    );
  });
}
