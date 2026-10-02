import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';
import 'package:studio/state/library_providers.dart';

final subsonicTracksProvider = StreamProvider<List<Track>>((ref) {
  final db = ref.watch(studioDatabaseProvider);
  return db.watchTracks(source: TrackLocator.subsonic);
});
