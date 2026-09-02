import 'package:studio/library/database.dart';

class TrackMetadataEdit {
  const TrackMetadataEdit({
    required this.title,
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.trackNumber,
  });

  factory TrackMetadataEdit.fromTrack(Track track) => TrackMetadataEdit(
    title: track.title,
    artist: track.artist,
    album: track.album,
    genre: track.genre,
    year: track.year == null || track.year! <= 0 ? null : track.year,
    trackNumber: track.trackNumber,
  );

  final String title;
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final int? trackNumber;

  TrackMetadataEdit normalized() => TrackMetadataEdit(
    title: title.trim(),
    artist: _optional(artist),
    album: _optional(album),
    genre: _optional(genre),
    year: year,
    trackNumber: trackNumber,
  );

  String? validate() {
    final value = normalized();
    if (value.title.isEmpty) return 'Title cannot be empty.';
    if (value.year case final year?) {
      if (year < 1000 || year > 2100) return 'Year must be 1000–2100.';
    }
    if (value.trackNumber case final number?) {
      if (number < 1 || number > 9999) {
        return 'Track number must be 1–9999.';
      }
    }
    return null;
  }

  List<MetadataChange> changesFrom(Track track) {
    final next = normalized();
    return [
      if (track.title != next.title)
        MetadataChange('Title', track.title, next.title),
      if (_optional(track.artist) != next.artist)
        MetadataChange('Artist', track.artist, next.artist),
      if (_optional(track.album) != next.album)
        MetadataChange('Album', track.album, next.album),
      if (_optional(track.genre) != next.genre)
        MetadataChange('Genre', track.genre, next.genre),
      if (_positive(track.year) != next.year)
        MetadataChange('Year', _text(track.year), _text(next.year)),
      if (_positive(track.trackNumber) != next.trackNumber)
        MetadataChange(
          'Track',
          _text(track.trackNumber),
          _text(next.trackNumber),
        ),
    ];
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static int? _positive(int? value) =>
      value == null || value <= 0 ? null : value;
  static String? _text(int? value) => _positive(value)?.toString();
}

class MetadataChange {
  const MetadataChange(this.field, this.before, this.after);

  final String field;
  final String? before;
  final String? after;
}
