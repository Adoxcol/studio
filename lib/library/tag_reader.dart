import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

class ParsedTags {
  const ParsedTags({
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.sampleRateHz,
    this.trackNumber,
    this.genre,
    this.artwork,
    this.artworkMime,
    this.year,
    this.readSucceeded = true,
  });

  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int? sampleRateHz;
  final int? trackNumber;
  final String? genre;
  final Uint8List? artwork;
  final String? artworkMime;
  final int? year;

  /// False means a read failed, not that the file has no optional tags.
  final bool readSucceeded;
}

class TagReader {
  const TagReader();

  ParsedTags read(File file, {bool getImage = false}) {
    final fallbackTitle = p.basenameWithoutExtension(file.path);
    try {
      final meta = readMetadata(file, getImage: getImage);
      final picture = getImage ? _cover(meta.pictures) : null;
      return ParsedTags(
        title: _nonEmpty(meta.title) ?? fallbackTitle,
        artist: _nonEmpty(meta.artist),
        album: _nonEmpty(meta.album),
        duration: meta.duration,
        sampleRateHz: meta.sampleRate,
        trackNumber: meta.trackNumber,
        genre: _firstGenre(meta.genres),
        artwork: picture?.bytes,
        artworkMime: picture?.mimetype,
        year: _year(meta.year),
      );
    } on Object {
      return ParsedTags(title: fallbackTitle, readSucceeded: false);
    }
  }

  static Picture? _cover(List<Picture> pictures) {
    if (pictures.isEmpty) return null;
    for (final picture in pictures) {
      if (picture.pictureType == PictureType.coverFront &&
          picture.bytes.isNotEmpty) {
        return picture;
      }
    }
    for (final picture in pictures) {
      if (picture.bytes.isNotEmpty) return picture;
    }
    return null;
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _firstGenre(List<String> genres) {
    for (final genre in genres) {
      final trimmed = _nonEmpty(genre);
      if (trimmed != null) return trimmed;
    }
    return null;
  }

  static int? _year(DateTime? value) {
    final year = value?.year;
    if (year == null || year < 1000 || year > 2100) return null;
    return year;
  }
}
