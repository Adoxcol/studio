import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/state/library_providers.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_core_providers.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_scan_providers.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_artists_providers.dart';

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
    } catch (error) {
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
