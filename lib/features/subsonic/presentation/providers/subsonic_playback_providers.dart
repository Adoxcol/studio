import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_core_providers.dart';

class SubsonicPlaybackService {
  SubsonicPlaybackService(this.ref);

  final Ref ref;

  Future<void> playSong(SubsonicSong song) async {
    await playSongs([song], startIndex: 0);
  }

  Future<void> playSongs(List<SubsonicSong> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    final db = ref.read(studioDatabaseProvider);
    final client = ref.read(subsonicClientProvider);

    final companions = <TracksCompanion>[];
    for (final song in songs) {
      companions.add(
        TracksCompanion.insert(
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
          artworkPath: Value(
            client?.buildCoverArtUri(song.coverArtId)?.toString(),
          ),
        ),
      );
    }

    await db.upsertTracks(companions);

    final locators = songs.map((s) => s.id).toList();

    // Process in chunks to avoid sqlite variable limits (SQLITE_MAX_VARIABLE_NUMBER = 999 or 32766)
    final Map<String, int> locatorToId = {};
    for (var i = 0; i < locators.length; i += 900) {
      final chunk = locators.skip(i).take(900).toList();
      final tracks =
          await (db.select(db.tracks)..where(
                (t) =>
                    t.locator.isIn(chunk) &
                    t.source.equals(TrackLocator.subsonic),
              ))
              .get();
      for (final t in tracks) {
        locatorToId[t.locator] = t.id;
      }
    }

    final trackIds = locators.map((loc) => locatorToId[loc]!).toList();

    final playback = ref.read(playbackControllerProvider.notifier);
    await playback.playTracks(trackIds, startIndex: startIndex);
  }

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final playback = ref.read(playbackControllerProvider.notifier);
    await playback.playTracks(
      tracks.map((t) => t.id).toList(),
      startIndex: startIndex,
    );
  }

  Future<void> clearSubsonicCache() async {
    final db = ref.read(studioDatabaseProvider);
    await (db.delete(
      db.tracks,
    )..where((t) => t.source.equals(TrackLocator.subsonic))).go();
  }
}

final subsonicPlaybackServiceProvider = Provider<SubsonicPlaybackService>((
  ref,
) {
  return SubsonicPlaybackService(ref);
});
