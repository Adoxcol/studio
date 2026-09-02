import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/metadata_editor/domain/track_metadata_edit.dart';
import 'package:studio/library/tag_reader.dart';

class TrackMetadataWriter {
  const TrackMetadataWriter();

  static const writableExtensions = {'mp3', 'mp4', 'm4a', 'flac', 'wav', 'ape'};

  bool supports(String path) => writableExtensions.contains(
    p.extension(path).replaceFirst('.', '').toLowerCase(),
  );

  Future<FileStat> write(String path, TrackMetadataEdit edit) {
    return Isolate.run(() => _writeVerified(path, edit.normalized()));
  }

  static FileStat _writeVerified(String path, TrackMetadataEdit edit) {
    final original = File(path);
    if (!original.existsSync()) {
      throw const FileSystemException('The audio file no longer exists.');
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('$path.studio-edit-$suffix');
    final backup = File('$path.studio-backup-$suffix');
    try {
      original.copySync(temporary.path);
      updateMetadata(temporary, (metadata) {
        metadata
          ..setTitle(edit.title)
          ..setArtist(edit.artist ?? '')
          ..setAlbum(edit.album ?? '')
          ..setGenres(edit.genre == null ? const [] : [edit.genre!])
          ..setYear(edit.year == null ? null : DateTime(edit.year!))
          ..setTrackNumber(edit.trackNumber);
      });
      final verified = const TagReader().read(temporary);
      if (!verified.readSucceeded ||
          verified.title.trim() != edit.title ||
          _optional(verified.artist) != edit.artist ||
          _optional(verified.album) != edit.album ||
          _optional(verified.genre) != edit.genre ||
          verified.year != edit.year ||
          verified.trackNumber != edit.trackNumber) {
        throw const FormatException(
          'The file format did not preserve every requested tag.',
        );
      }
      original.renameSync(backup.path);
      try {
        temporary.renameSync(path);
      } on Object {
        backup.renameSync(path);
        rethrow;
      }
      try {
        backup.deleteSync();
      } on Object {
        // The edit is already committed. A harmless backup is safer than
        // reporting failure after the database and file have diverged.
      }
      return File(path).statSync();
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
      if (backup.existsSync() && !original.existsSync()) {
        backup.renameSync(path);
      }
    }
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final trackMetadataWriterProvider = Provider<TrackMetadataWriter>(
  (ref) => const TrackMetadataWriter(),
);
