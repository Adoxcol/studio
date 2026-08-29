import 'package:flutter/foundation.dart';
import 'package:studio/core/app_info.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_ids.dart';
import 'package:studio/state/playback_provider.dart';

const int kDiscordTextLimit = 128;
const int kDiscordButtonLimit = 32;

/// What we send to Discord for a playback snapshot. Null means clear.
@immutable
class DiscordPresenceView {
  const DiscordPresenceView({
    required this.name,
    required this.details,
    required this.playing,
    this.state,
    this.album,
    this.largeImage = kDiscordLargeImageKey,
    this.start,
    this.end,
  });

  /// Compact 🎵 line: `artist - track`.
  final String name;

  /// First line of the activity card: track title.
  final String details;

  /// Second line: artist.
  final String? state;

  /// Third line / cover hover: album.
  final String? album;

  /// Cover: an `mp:external/...` media-proxy address (see
  /// [discordExternalAsset]), or a portal asset key (`studio`).
  final String largeImage;

  final bool playing;

  /// Progress bar start. Omitted when paused.
  final DateTime? start;

  /// Progress bar end. Omitted when paused or duration is unknown.
  final DateTime? end;

  String get buttonLabel =>
      clipDiscordText(playing ? 'Play' : 'Pause', limit: kDiscordButtonLimit);

  String get smallImageKey =>
      playing ? kDiscordPlayImageKey : kDiscordPauseImageKey;

  String get smallImageText => playing ? 'Playing' : 'Paused';

  String get buttonUrl => kAppHomepage;

  /// IPC timestamps are Unix seconds. Both start and end are required
  /// for Discord to draw the listening progress bar.
  Map<String, int>? get timestampsPayload =>
      discordTimestampsPayload(start: start, end: end);

  @override
  bool operator ==(Object other) {
    return other is DiscordPresenceView &&
        other.name == name &&
        other.details == details &&
        other.state == state &&
        other.album == album &&
        other.largeImage == largeImage &&
        other.playing == playing &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode =>
      Object.hash(name, details, state, album, largeImage, playing, start, end);
}

/// Maps library playback onto a Discord Listening activity.
///
/// Discord only has two body lines (`details`, `state`) plus `name` for the
/// compact 🎵 row. Album sits on cover hover (`large_text`). Paused keeps the
/// card but drops timestamps so the bar does not keep moving.
DiscordPresenceView? discordPresenceFor(
  PlaybackUiState playback, {
  DateTime? now,
  String? largeImage,
}) {
  if (playback.trackId == null) return null;
  final details = clipDiscordText(playback.title);
  if (details.isEmpty) return null;
  final artist = _optionalText(playback.artist);
  final album = _optionalText(playback.album);
  DateTime? start;
  DateTime? end;
  if (playback.playing && playback.duration > Duration.zero) {
    final clock = now ?? DateTime.now();
    start = clock.subtract(playback.position);
    end = start.add(playback.duration);
  }
  return DiscordPresenceView(
    name: discordCompactName(title: details, artist: artist),
    details: details,
    state: artist,
    album: album,
    largeImage: discordLargeImage(largeImage),
    playing: playback.playing,
    start: start,
    end: end,
  );
}

String discordCompactName({required String title, String? artist}) {
  if (artist == null || artist.isEmpty) return title;
  return clipDiscordText('$artist - $title');
}

String? _optionalText(String? value) {
  if (value == null) return null;
  final clipped = clipDiscordText(value);
  return clipped.isEmpty ? null : clipped;
}

String clipDiscordText(String value, {int limit = kDiscordTextLimit}) {
  final trimmed = value.trim();
  if (trimmed.length <= limit) return trimmed;
  return trimmed.substring(0, limit);
}

/// Discord's IPC SET_ACTIVITY expects Unix time in seconds. Milliseconds
/// are ignored and the progress bar never appears.
Map<String, int>? discordTimestampsPayload({
  required DateTime? start,
  DateTime? end,
}) {
  if (start == null) return null;
  return {
    'start': start.millisecondsSinceEpoch ~/ 1000,
    if (end != null) 'end': end.millisecondsSinceEpoch ~/ 1000,
  };
}
