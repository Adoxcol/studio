import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/features/subsonic/data/subsonic_artist_pictures.dart';
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
    if (info.isConnected) {
      Future.microtask(_autoScanIfEmpty);
      Future.microtask(_syncArtistPictures);
    }
  }

  Future<void> _autoScanIfEmpty() async {
    final db = ref.read(studioDatabaseProvider);
    final cached = await db.watchTracks(source: TrackLocator.subsonic).first;
    if (cached.isEmpty) {
      ref.read(subsonicScanProvider.notifier).startScan();
    }
  }

  Future<void> _syncArtistPictures() async {
    final client = ref.read(subsonicClientProvider);
    final sync = ref.read(subsonicArtistPictureSyncProvider);
    if (client == null || sync == null) return;
    try {
      await sync.sync(await client.getArtists());
    } on Object catch (error) {
      // Artist portraits are an optional background enhancement. Connection
      // and library browsing must continue if the server response is invalid.
      debugPrint('Navidrome artist portraits unavailable: $error');
    }
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
  final artists = await client.getArtists();
  unawaited(ref.read(subsonicArtistPictureSyncProvider)?.sync(artists));
  return artists;
});

/// Shared by the connect-time sync, the artists list and the library scan so
/// every artist gets its portrait by the same rules, one run at a time.
final subsonicArtistPictureSyncProvider = Provider<SubsonicArtistPictureSync?>((
  ref,
) {
  final client = ref.watch(subsonicClientProvider);
  if (client == null) return null;
  return SubsonicArtistPictureSync(
    repository: ref.watch(artistPictureRepositoryProvider),
    fetch: client.artistPictureBytes,
  );
});

class SubsonicAlbumSortNotifier extends Notifier<SubsonicAlbumSort> {
  @override
  SubsonicAlbumSort build() => SubsonicAlbumSort.alphabeticalByName;

  void setSort(SubsonicAlbumSort sort) {
    state = sort;
  }
}

final subsonicAlbumSortProvider =
    NotifierProvider<SubsonicAlbumSortNotifier, SubsonicAlbumSort>(
      SubsonicAlbumSortNotifier.new,
    );

class SubsonicAlbumsState {
  const SubsonicAlbumsState({
    this.albums = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<SubsonicAlbum> albums;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  SubsonicAlbumsState copyWith({
    List<SubsonicAlbum>? albums,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return SubsonicAlbumsState(
      albums: albums ?? this.albums,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class SubsonicAlbumsNotifier extends Notifier<SubsonicAlbumsState> {
  static const int pageSize = 100;

  @override
  SubsonicAlbumsState build() {
    final conn = ref.watch(subsonicConnectionProvider);
    final sort = ref.watch(subsonicAlbumSortProvider);

    if (!conn.isConnected) {
      return const SubsonicAlbumsState();
    }

    Future.microtask(() => loadInitial(sort));
    return const SubsonicAlbumsState(isLoading: true);
  }

  Future<void> loadInitial(SubsonicAlbumSort sort) async {
    final client = ref.read(subsonicClientProvider);
    if (client == null) {
      state = const SubsonicAlbumsState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final albums = await client.getAlbumList(
        type: sort.apiValue,
        size: pageSize,
        offset: 0,
      );
      state = SubsonicAlbumsState(
        albums: albums,
        isLoading: false,
        hasMore: albums.length >= pageSize,
      );
    } catch (e) {
      state = SubsonicAlbumsState(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final client = ref.read(subsonicClientProvider);
    final sort = ref.read(subsonicAlbumSortProvider);
    if (client == null) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await client.getAlbumList(
        type: sort.apiValue,
        size: pageSize,
        offset: state.albums.length,
      );
      state = state.copyWith(
        albums: [...state.albums, ...more],
        isLoadingMore: false,
        hasMore: more.length >= pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> loadAll() async {
    if (state.isLoading) return;
    final client = ref.read(subsonicClientProvider);
    final sort = ref.read(subsonicAlbumSortProvider);
    if (client == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final all = await client.getAllAlbums(type: sort.apiValue, pageSize: 500);
      state = SubsonicAlbumsState(
        albums: all,
        isLoading: false,
        hasMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final subsonicAlbumsNotifierProvider =
    NotifierProvider<SubsonicAlbumsNotifier, SubsonicAlbumsState>(
      SubsonicAlbumsNotifier.new,
    );

final subsonicAlbumsProvider = Provider<AsyncValue<List<SubsonicAlbum>>>((ref) {
  final state = ref.watch(subsonicAlbumsNotifierProvider);
  if (state.isLoading) {
    return const AsyncValue.loading();
  }
  if (state.error != null) {
    return AsyncValue.error(state.error!, StackTrace.current);
  }
  return AsyncValue.data(state.albums);
});

class SubsonicScanNotifier extends Notifier<SubsonicScanState> {
  bool _isCancelled = false;

  /// Tracks are written in batches: each write makes every live tracks query
  /// (the whole local library included) re-run, so per-album writes kept the
  /// UI busy for the entire scan.
  static const flushTracks = 2000;
  static const flushEvery = Duration(seconds: 2);

  /// Albums fetched at once. Servers handle a few parallel requests well,
  /// and waiting on one round trip per album made big libraries slow.
  static const albumConcurrency = 4;

  /// Progress is published at most this often; the final state always lands.
  static const progressEvery = Duration(milliseconds: 120);

  final _clock = Stopwatch();
  var _lastProgress = Duration.zero;

  @override
  SubsonicScanState build() => const SubsonicScanState();

  /// Publishes progress unless one went out within [progressEvery].
  void _progress(SubsonicScanState next, {bool force = false}) {
    final now = _clock.elapsed;
    if (!force && now - _lastProgress < progressEvery) {
      _pending = next;
      return;
    }
    _pending = null;
    _lastProgress = now;
    state = next;
  }

  SubsonicScanState? _pending;

  SubsonicScanState get _latest => _pending ?? state;

  void cancelScan() {
    _isCancelled = true;
    state = state.copyWith(isScanning: false);
  }

  Future<void> startScan() async {
    final client = ref.read(subsonicClientProvider);
    final db = ref.read(studioDatabaseProvider);
    if (client == null) return;

    _isCancelled = false;
    _pending = null;
    _clock
      ..reset()
      ..start();
    _lastProgress = -progressEvery;
    state = const SubsonicScanState(
      isScanning: true,
      statusMessage: 'Scanning albums...',
    );

    try {
      // 1. Fetch all albums
      final albums = await client.getAllAlbums(
        type: 'alphabeticalByName',
        pageSize: 500,
        onProgress: (count) {
          if (!_isCancelled) {
            state = state.copyWith(totalAlbums: count);
          }
        },
      );

      if (_isCancelled) return;
      state = state.copyWith(totalAlbums: albums.length);

      var scannedTracks = 0;
      final buffer = <TracksCompanion>[];
      var lastFlush = _clock.elapsed;
      Future<void> flush() async {
        if (buffer.isEmpty) return;
        final batch = List.of(buffer);
        buffer.clear();
        lastFlush = _clock.elapsed;
        await db.insertTracksIfNotExists(batch);
      }

      // 2. Fetch tracks for each album, a few at a time; write in batches
      for (var start = 0; start < albums.length; start += albumConcurrency) {
        if (_isCancelled) break;
        final window = albums.sublist(
          start,
          (start + albumConcurrency).clamp(0, albums.length),
        );
        _progress(
          _latest.copyWith(
            currentAlbum: start + 1,
            currentAlbumName: window.first.name,
            statusMessage: 'Scanning album ${start + 1} of ${albums.length}',
          ),
        );

        final results = await Future.wait([
          for (final album in window) client.getAlbum(album.id),
        ]);
        if (_isCancelled) break;

        for (final songs in results) {
          for (final song in songs) {
            buffer.add(
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
                  client.buildCoverArtUri(song.coverArtId)?.toString(),
                ),
              ),
            );
          }
          scannedTracks += songs.length;
        }
        if (buffer.length >= flushTracks ||
            _clock.elapsed - lastFlush >= flushEvery) {
          await flush();
        }

        final done = start + window.length;
        _progress(
          _latest.copyWith(
            currentAlbum: done,
            currentAlbumName: window.last.name,
            statusMessage: 'Scanning album $done of ${albums.length}',
            totalTracks: scannedTracks,
          ),
        );
      }

      // Keep what was fetched even when the scan is cancelled part-way.
      await flush();
      if (_isCancelled) return;
      _progress(_latest, force: true);

      // 3. Fetch playlists from Navidrome
      state = state.copyWith(
        statusMessage: 'Fetching playlists...',
        currentAlbumName: '',
      );
      final remotePlaylists = await client.getPlaylists();
      state = state.copyWith(totalPlaylists: remotePlaylists.length);

      final existingPlaylists = await db.allPlaylists();
      var syncedPlaylists = 0;

      for (final rp in remotePlaylists) {
        if (_isCancelled) break;
        state = state.copyWith(
          currentPlaylistName: rp.name,
          statusMessage: 'Fetching playlist: ${rp.name}',
        );

        final playlistSongs = await client.getPlaylist(rp.id);
        if (_isCancelled) break;

        final playlistTracks = await db.getOrInsertTracks([
          for (final song in playlistSongs)
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
                client.buildCoverArtUri(song.coverArtId)?.toString(),
              ),
            ),
        ]);
        final trackIds = [for (final track in playlistTracks) track.id];

        final existing = existingPlaylists
            .where((p) => p.name == rp.name && p.smartRules == null)
            .firstOrNull;
        final int playlistId;
        if (existing != null) {
          playlistId = existing.id;
        } else {
          playlistId = await db.createPlaylist(rp.name);
        }
        await db.replacePlaylistTracks(playlistId, trackIds);
        syncedPlaylists++;
        state = state.copyWith(syncedPlaylists: syncedPlaylists);
      }

      if (_isCancelled) return;

      // 4. Fetch artist portraits from Navidrome
      state = state.copyWith(
        statusMessage: 'Syncing artist portraits...',
        currentPlaylistName: '',
      );
      final remoteArtists = await client.getArtists();
      await ref
          .read(subsonicArtistPictureSyncProvider)
          ?.sync(
            remoteArtists,
            isCancelled: () => _isCancelled,
            onProgress: (done, total) => _progress(
              _latest.copyWith(
                totalArtists: total,
                syncedArtists: done,
                statusMessage: 'Fetching portraits: $done of $total',
              ),
            ),
          );

      if (!_isCancelled) {
        _pending = null;
        state = _latest.copyWith(
          isScanning: false,
          isCompleted: true,
          currentAlbumName: '',
          currentPlaylistName: '',
          currentArtistName: '',
          statusMessage: null,
        );
      }
    } catch (e) {
      if (!_isCancelled) {
        state = state.copyWith(
          isScanning: false,
          error: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}

final subsonicScanProvider =
    NotifierProvider<SubsonicScanNotifier, SubsonicScanState>(
      SubsonicScanNotifier.new,
    );

final subsonicTracksProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(studioDatabaseProvider);
  return db.watchTracks(source: TrackLocator.subsonic);
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
