import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

class ParsedTags {
  const ParsedTags({
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.trackNumber,
    this.genre,
  });

  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int? trackNumber;
  final String? genre;
}

class TagReader {
  const TagReader();

  ParsedTags read(File file) {
    final fallbackTitle = p.basenameWithoutExtension(file.path);
    try {
      final meta = readMetadata(file, getImage: false);
      return ParsedTags(
        title: _nonEmpty(meta.title) ?? fallbackTitle,
        artist: _nonEmpty(meta.artist),
        album: _nonEmpty(meta.album),
        duration: meta.duration,
        trackNumber: meta.trackNumber,
        genre: _firstGenre(meta.genres),
      );
    } on Object {
      return ParsedTags(title: fallbackTitle);
    }
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
}
