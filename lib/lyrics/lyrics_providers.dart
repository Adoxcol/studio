import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/lyrics/lrc.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_cache.dart';
import 'package:studio/lyrics/lyrics_query.dart';
import 'package:studio/lyrics/lyrics_repository.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

final lyricsLookupProvider = Provider<LyricsLookup>((ref) => LrclibClient());

final lyricsCacheProvider = Provider<LyricsCache>((ref) => MemoryLyricsCache());

final lyricsRepositoryProvider = Provider<LyricsRepository>((ref) {
  return LyricsRepository(
    lookup: ref.watch(lyricsLookupProvider),
    cache: ref.watch(lyricsCacheProvider),
  );
});

final currentLyricsProvider = FutureProvider<LyricsDocument?>((ref) async {
  final snapshot = ref.watch(
    playbackControllerProvider.select(
      (s) => (
        trackId: s.trackId,
        title: s.title,
        artist: s.artist,
        duration: s.duration,
      ),
    ),
  );
  final id = snapshot.trackId;
  if (id == null) return null;
  final track = await ref.read(studioDatabaseProvider).trackById(id);
  final title = (track?.title ?? snapshot.title).trim();
  final artist = (track?.artist ?? snapshot.artist)?.trim();
  if (title.isEmpty || artist == null || artist.isEmpty) {
    return LyricsDocument.none;
  }
  final taggedSeconds = ((track?.durationMs ?? 0) / 1000).round();
  final engineSeconds = (snapshot.duration.inMilliseconds / 1000).round();
  final durationSeconds = taggedSeconds >= 1
      ? taggedSeconds
      : (engineSeconds >= 1 ? engineSeconds : null);
  return ref
      .read(lyricsRepositoryProvider)
      .load(
        LyricsQuery(
          title: title,
          artist: artist,
          album: track?.album,
          durationSeconds: durationSeconds,
        ),
      );
});
