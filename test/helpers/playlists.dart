import 'package:studio/library/database.dart';

/// A regular playlist containing a repeated occurrence of A.
Future<int> seedPlaylist(StudioDatabase db) async {
  for (final title in ['A', 'B', 'C']) {
    await db.upsertTrack(
      TracksCompanion.insert(locator: '/$title.flac', title: title),
    );
  }
  final id = await db.createPlaylist('Original');
  final tracks = await db.allTracks();
  for (final track in [tracks[0], tracks[1], tracks[0], tracks[2]]) {
    await db.addTrackToPlaylist(playlistId: id, trackId: track.id);
  }
  return id;
}
