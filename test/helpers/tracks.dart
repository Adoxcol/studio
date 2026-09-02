import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';

Track testTrack({
  int id = 1,
  String title = 'Nocturne in Blue',
  String? artist = 'Aria Solvang',
  String? album = 'Afterglow',
  int? durationMs = 238000,
  int? fileSizeBytes,
  int? sampleRateHz,
  int? trackNumber = 1,
  String? genre = 'Neo-classical',
  String? locator,
  String? artworkPath,
  int? year,
  int? fileModifiedMs,
  int? folderId = 1,
  DateTime? indexedAt,
}) {
  return Track(
    id: id,
    source: TrackLocator.local,
    locator: locator ?? '/music/$id.flac',
    title: title,
    artist: artist,
    album: album,
    durationMs: durationMs,
    fileSizeBytes: fileSizeBytes,
    sampleRateHz: sampleRateHz,
    trackNumber: trackNumber,
    genre: genre,
    artworkPath: artworkPath,
    year: year,
    fileModifiedMs: fileModifiedMs,
    folderId: folderId,
    indexedAt: indexedAt ?? DateTime.utc(2026, 1, id.clamp(1, 28)),
  );
}
