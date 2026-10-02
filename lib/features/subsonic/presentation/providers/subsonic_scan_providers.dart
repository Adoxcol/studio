import 'package:studio/state/library_providers.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/subsonic/data/subsonic_track_rows.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/library/database.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_core_providers.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_artists_providers.dart';

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
        await db.syncRemoteTracks(batch);
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
            buffer.add(subsonicTrackRow(song, client));
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
          for (final song in playlistSongs) subsonicTrackRow(song, client),
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
