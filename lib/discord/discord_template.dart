import 'package:path/path.dart' as p;
import 'package:studio/core/time_format.dart';
import 'package:studio/state/playback_provider.dart';

final _tokenPattern = RegExp(r'\{([a-z_]+)\}');
final _optionalPattern = RegExp(r'\[([^\[\]]*)\]');

/// Expands Discord text templates. Text in square brackets is optional and is
/// removed when any variable inside it is unavailable.
String renderDiscordTemplate(String template, PlaybackUiState playback) {
  final values = discordTemplateValues(playback);
  var rendered = template;
  while (_optionalPattern.hasMatch(rendered)) {
    rendered = rendered.replaceAllMapped(_optionalPattern, (match) {
      final content = match.group(1)!;
      final tokens = _tokenPattern.allMatches(content);
      if (tokens.any((token) => (values[token.group(1)] ?? '').isEmpty)) {
        return '';
      }
      return _replaceTokens(content, values);
    });
  }
  return _replaceTokens(rendered, values).trim();
}

Map<String, String> discordTemplateValues(PlaybackUiState playback) {
  final locator = playback.locator?.trim();
  final filename = locator == null || locator.isEmpty
      ? ''
      : p.basename(locator);
  final extension = filename.isEmpty
      ? ''
      : p.extension(filename).replaceFirst('.', '').toLowerCase();
  final format = extension.toUpperCase();
  final lossless = _losslessFormats.contains(extension) ? 'Lossless' : '';
  final bitrate = _averageBitrate(playback.fileSizeBytes, playback.duration);
  final sampleRate = _sampleRate(playback.sampleRateHz);
  final quality = [
    if (format.isNotEmpty) format,
    if (lossless.isNotEmpty) lossless,
    if (bitrate.isNotEmpty) bitrate,
    if (sampleRate.isNotEmpty) sampleRate,
  ].join(' • ');

  return {
    'title': playback.title.trim(),
    'artist': playback.artist?.trim() ?? '',
    'album': playback.album?.trim() ?? '',
    'genre': playback.genre?.trim() ?? '',
    'year': playback.year == null || playback.year! <= 0
        ? ''
        : '${playback.year}',
    'filename': filename,
    'file_stem': filename.isEmpty ? '' : p.basenameWithoutExtension(filename),
    'extension': extension,
    'format': format,
    'bitrate': bitrate,
    'sample_rate': sampleRate,
    'hz': sampleRate,
    'lossless': lossless,
    'quality': quality,
    'duration': playback.duration > Duration.zero
        ? formatDuration(playback.duration)
        : '',
    'status': playback.playing ? 'Playing' : 'Paused',
  };
}

String _replaceTokens(String value, Map<String, String> values) {
  return value.replaceAllMapped(
    _tokenPattern,
    (match) => values[match.group(1)] ?? '',
  );
}

String _averageBitrate(int? bytes, Duration duration) {
  if (bytes == null || bytes <= 0 || duration <= Duration.zero) return '';
  final kbps = (bytes * 8 / duration.inMilliseconds).round();
  return '$kbps kbps';
}

String _sampleRate(int? hz) {
  if (hz == null || hz <= 0) return '';
  final khz = hz / 1000;
  final value = khz == khz.roundToDouble()
      ? khz.toStringAsFixed(0)
      : khz.toStringAsFixed(1);
  return '$value kHz';
}

const _losslessFormats = {
  'flac',
  'alac',
  'wav',
  'wave',
  'aif',
  'aiff',
  'ape',
  'wv',
  'tta',
  'tak',
  'dsf',
  'dff',
};
