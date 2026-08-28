import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/app.dart';
import 'package:studio/library/database.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/state/library_providers.dart';

Widget testStudioApp({
  required StudioDatabase db,
  required AudioEngine engine,
  List<Track> tracks = const [],
}) {
  return ProviderScope(
    overrides: [
      studioDatabaseProvider.overrideWithValue(db),
      audioEngineProvider.overrideWithValue(engine),
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
    ],
    child: const StudioApp(),
  );
}
