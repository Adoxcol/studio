/// One listen as the scrobbling services see it.
class ScrobbleTrack {
  const ScrobbleTrack({
    required this.artist,
    required this.title,
    required this.startedAt,
    this.album,
    this.duration = Duration.zero,
  });

  final String artist;
  final String title;
  final String? album;
  final Duration duration;

  /// When playback of this listen began, in UTC.
  final DateTime startedAt;

  int get startedAtSeconds => startedAt.millisecondsSinceEpoch ~/ 1000;

  Map<String, Object?> toJson() => {
    'artist': artist,
    'title': title,
    if (album != null) 'album': album,
    'durationMs': duration.inMilliseconds,
    'startedAt': startedAt.toUtc().toIso8601String(),
  };

  static ScrobbleTrack? fromJson(Object? json) {
    if (json is! Map) return null;
    final artist = json['artist'];
    final title = json['title'];
    final started = DateTime.tryParse('${json['startedAt']}');
    if (artist is! String || title is! String || started == null) return null;
    final album = json['album'];
    final duration = json['durationMs'];
    return ScrobbleTrack(
      artist: artist,
      title: title,
      album: album is String ? album : null,
      duration: Duration(milliseconds: duration is int ? duration : 0),
      startedAt: started.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScrobbleTrack &&
      other.artist == artist &&
      other.title == title &&
      other.album == album &&
      other.duration == duration &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(artist, title, album, duration, startedAt);

  @override
  String toString() => 'ScrobbleTrack($artist – $title @ $startedAt)';
}
