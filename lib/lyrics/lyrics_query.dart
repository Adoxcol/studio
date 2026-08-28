import 'package:flutter/foundation.dart';

@immutable
class LyricsQuery {
  const LyricsQuery({
    required this.title,
    required this.artist,
    this.album,
    this.durationSeconds,
  });

  final String title;
  final String artist;
  final String? album;
  final int? durationSeconds;

  String get cacheKey {
    final albumPart = (album ?? '').trim().toLowerCase();
    final durationPart = '${durationSeconds ?? 0}';
    return '${artist.trim().toLowerCase()}|${title.trim().toLowerCase()}|$albumPart|$durationPart';
  }

  @override
  bool operator ==(Object other) {
    return other is LyricsQuery &&
        other.title == title &&
        other.artist == artist &&
        other.album == album &&
        other.durationSeconds == durationSeconds;
  }

  @override
  int get hashCode => Object.hash(title, artist, album, durationSeconds);
}
