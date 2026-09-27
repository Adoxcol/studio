import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:studio/features/subsonic/data/subsonic_offline_store.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';

/// Null until main wires a real folder; offline copies are then disabled.
final subsonicOfflineStoreProvider = Provider<SubsonicOfflineStore?>(
  (ref) => null,
);

final subsonicDownloadHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The downloaded copy of a song for the connected server, if any.
File? subsonicOfflineFile(Ref ref, String songId) {
  final store = ref.read(subsonicOfflineStoreProvider);
  final config = ref.read(subsonicConfigProvider);
  if (store == null || config == null) return null;
  return store.fileFor(SubsonicOfflineStore.serverKey(config), songId);
}

@immutable
class OfflineDownloadsState {
  const OfflineDownloadsState({
    this.available = false,
    this.downloaded = const {},
    this.active = const {},
    this.failed = const {},
    this.totalBytes = 0,
  });

  /// False when no server is configured or storage is not wired.
  final bool available;

  /// Song ids with a complete offline copy on the connected server.
  final Set<String> downloaded;

  /// Queued or running downloads: song id to progress (null = unknown).
  final Map<String, double?> active;

  /// Song id to the reason its last download failed.
  final Map<String, String> failed;

  /// Bytes used by offline copies across all servers.
  final int totalBytes;

  OfflineDownloadsState copyWith({
    Set<String>? downloaded,
    Map<String, double?>? active,
    Map<String, String>? failed,
    int? totalBytes,
  }) {
    return OfflineDownloadsState(
      available: available,
      downloaded: downloaded ?? this.downloaded,
      active: active ?? this.active,
      failed: failed ?? this.failed,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

class OfflineDownloadsNotifier extends Notifier<OfflineDownloadsState> {
  final _queue = <String>[];
  OfflineCancelToken? _running;
  String? _runningId;
  var _generation = 0;

  SubsonicOfflineStore? get _store => ref.read(subsonicOfflineStoreProvider);

  String? get _server {
    final config = ref.read(subsonicConfigProvider);
    return config == null ? null : SubsonicOfflineStore.serverKey(config);
  }

  @override
  OfflineDownloadsState build() {
    final store = ref.watch(subsonicOfflineStoreProvider);
    final config = ref.watch(subsonicConfigProvider);
    _generation++;
    _queue.clear();
    _running?.cancel();
    _running = null;
    _runningId = null;
    if (store == null || config == null) return const OfflineDownloadsState();
    final server = SubsonicOfflineStore.serverKey(config);
    return OfflineDownloadsState(
      available: true,
      downloaded: store.downloadedIds(server),
      totalBytes: store.totalBytes(),
    );
  }

  /// Queues [songIds] that are not already downloaded or queued.
  void download(Iterable<String> songIds) {
    if (!state.available) return;
    final fresh = [
      for (final id in songIds.toSet())
        if (!state.downloaded.contains(id) && !state.active.containsKey(id)) id,
    ];
    if (fresh.isEmpty) return;
    _queue.addAll(fresh);
    state = state.copyWith(
      active: {...state.active, for (final id in fresh) id: null},
      failed: {...state.failed}..removeWhere((id, _) => fresh.contains(id)),
    );
    if (_runningId == null) unawaited(_pump());
  }

  void cancel(String songId) {
    if (_runningId == songId) {
      _running?.cancel();
    } else if (!_queue.remove(songId)) {
      return;
    }
    // Drop it from view now; a slow server may not answer for a while.
    state = state.copyWith(active: {...state.active}..remove(songId));
  }

  void remove(Iterable<String> songIds) {
    final store = _store;
    final server = _server;
    if (store == null || server == null) return;
    final ids = songIds.toSet();
    for (final id in ids) {
      cancel(id);
    }
    store.remove(server, ids);
    state = state.copyWith(
      downloaded: {...state.downloaded}..removeAll(ids),
      totalBytes: store.totalBytes(),
    );
  }

  void removeAll() {
    final store = _store;
    if (store == null) return;
    _queue.clear();
    _running?.cancel();
    store.removeAll();
    state = state.copyWith(
      downloaded: const {},
      active: const {},
      failed: const {},
      totalBytes: 0,
    );
  }

  Future<void> _pump() async {
    final generation = _generation;
    bool live() => ref.mounted && generation == _generation;
    while (_queue.isNotEmpty && live()) {
      final id = _queue.removeAt(0);
      final store = _store;
      final server = _server;
      final client = ref.read(subsonicClientProvider);
      if (store == null || server == null || client == null) {
        _finish(id, error: 'Connect to the server to download.');
        continue;
      }
      final token = OfflineCancelToken();
      _running = token;
      _runningId = id;
      var lastShown = -1.0;
      try {
        await store.download(
          server: server,
          songId: id,
          uri: client.buildDownloadUri(id),
          client: ref.read(subsonicDownloadHttpClientProvider),
          cancel: token,
          onProgress: (received, total) {
            if (total == null || total <= 0 || !live()) {
              return;
            }
            final progress = received / total;
            if (progress - lastShown < 0.01 && progress < 1) return;
            lastShown = progress;
            state = state.copyWith(active: {...state.active, id: progress});
          },
        );
        if (!live()) return;
        if (token.cancelled) {
          // Finished just as the user cancelled: honour the cancel.
          store.remove(server, [id]);
          _finish(id, totalBytes: store.totalBytes());
          continue;
        }
        _finish(id, done: true, totalBytes: store.totalBytes());
      } on OfflineDownloadCancelled {
        if (live()) _finish(id);
      } on Object catch (error) {
        if (!live()) return;
        _finish(
          id,
          error: error is OfflineDownloadFailed
              ? error.message
              : 'Download failed. Check the connection and try again.',
        );
      } finally {
        if (ref.mounted && identical(_running, token)) {
          _running = null;
          _runningId = null;
        }
      }
    }
  }

  void _finish(String id, {bool done = false, String? error, int? totalBytes}) {
    state = state.copyWith(
      active: {...state.active}..remove(id),
      downloaded: done ? {...state.downloaded, id} : null,
      failed: error == null ? null : {...state.failed, id: error},
      totalBytes: totalBytes,
    );
  }
}

final offlineDownloadsProvider =
    NotifierProvider<OfflineDownloadsNotifier, OfflineDownloadsState>(
      OfflineDownloadsNotifier.new,
    );
