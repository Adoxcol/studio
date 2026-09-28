import 'package:drift/drift.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';

/// The library row for a server song. Its date added is the server's, so
/// "Date added" in the Library matches Navidrome's Recently Added rather than
/// the time Studio happened to scan it.
TracksCompanion subsonicTrackRow(SubsonicSong song, SubsonicClient client) {
  final created = song.created;
  return TracksCompanion.insert(
    source: const Value(TrackLocator.subsonic),
    locator: song.id,
    title: song.title,
    artist: Value(song.artist),
    album: Value(song.album),
    durationMs: Value(song.durationSeconds * 1000),
    fileSizeBytes: Value(song.sizeBytes),
    year: Value(song.year),
    trackNumber: Value(song.trackNumber),
    genre: Value(song.genre),
    artworkPath: Value(client.buildCoverArtUri(song.coverArtId)?.toString()),
    indexedAt: created == null ? const Value.absent() : Value(created),
  );
}
