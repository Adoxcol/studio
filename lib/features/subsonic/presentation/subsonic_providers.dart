import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

final subsonicSettingsStoreProvider = Provider<SubsonicSettingsStore>((ref) {
  return MemorySubsonicSettingsStore();
});

class SubsonicConfigNotifier extends Notifier<SubsonicServerConfig?> {
  @override
  SubsonicServerConfig? build() {
    final store = ref.watch(subsonicSettingsStoreProvider);
    return store.load();
  }

  void updateConfig(SubsonicServerConfig? config) {
    state = config;
    ref.read(subsonicSettingsStoreProvider).save(config);
  }
}

final subsonicConfigProvider =
    NotifierProvider<SubsonicConfigNotifier, SubsonicServerConfig?>(
      SubsonicConfigNotifier.new,
    );

final subsonicClientProvider = Provider<SubsonicClient?>((ref) {
  final config = ref.watch(subsonicConfigProvider);
  if (config == null || config.serverUrl.isEmpty) return null;
  final client = SubsonicClient(config: config);
  ref.onDispose(client.dispose);
  return client;
});

class SubsonicConnectionNotifier extends Notifier<SubsonicConnectionInfo> {
  @override
  SubsonicConnectionInfo build() {
    final client = ref.watch(subsonicClientProvider);
    if (client == null) {
      return SubsonicConnectionInfo.disconnected;
    }
    // Auto-ping when client is initialized
    Future.microtask(ping);
    return const SubsonicConnectionInfo(
      status: SubsonicConnectionStatus.connecting,
    );
  }

  Future<void> ping() async {
    final client = ref.read(subsonicClientProvider);
    if (client == null) {
      state = SubsonicConnectionInfo.disconnected;
      return;
    }
    state = const SubsonicConnectionInfo(
      status: SubsonicConnectionStatus.connecting,
    );
    final info = await client.ping();
    state = info;
  }
}

final subsonicConnectionProvider =
    NotifierProvider<SubsonicConnectionNotifier, SubsonicConnectionInfo>(
      SubsonicConnectionNotifier.new,
    );

final subsonicArtistsProvider = FutureProvider<List<SubsonicArtist>>((
  ref,
) async {
  final conn = ref.watch(subsonicConnectionProvider);
  if (!conn.isConnected) return const [];
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  return client.getArtists();
});

final subsonicAlbumsProvider = FutureProvider<List<SubsonicAlbum>>((ref) async {
  final conn = ref.watch(subsonicConnectionProvider);
  if (!conn.isConnected) return const [];
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return const [];
  return client.getAlbumList(type: 'recent', size: 40);
});

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

    final trackIds = <int>[];
    for (final song in songs) {
      final companion = TracksCompanion.insert(
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
      );
      final track = await db.getOrInsertTrack(companion);
      trackIds.add(track.id);
    }

    final playback = ref.read(playbackControllerProvider.notifier);
    await playback.playTracks(trackIds, startIndex: startIndex);
  }
}

final subsonicPlaybackServiceProvider = Provider<SubsonicPlaybackService>((
  ref,
) {
  return SubsonicPlaybackService(ref);
});
