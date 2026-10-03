import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/features/subsonic/data/subsonic_artist_pictures.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_connection_providers.dart';
import 'package:studio/features/subsonic/presentation/providers/subsonic_core_providers.dart';

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
