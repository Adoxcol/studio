import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/app.dart';
import 'package:studio/library/database.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/lyrics/lyrics_providers.dart';
import 'package:studio/playback/audio_engine.dart';
import 'package:studio/state/library_providers.dart';

import '../lyrics/fake_lyrics_lookup.dart';

Widget testStudioApp({
  required StudioDatabase db,
  required AudioEngine engine,
  List<Track> tracks = const [],
  List<LibraryFolder> folders = const [],
  List extraOverrides = const [],
  LyricsLookup? lyricsLookup,
}) {
  return ProviderScope(
    overrides: [
      studioDatabaseProvider.overrideWithValue(db),
      audioEngineProvider.overrideWithValue(engine),
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      libraryFoldersProvider.overrideWith((ref) => Stream.value(folders)),
      lyricsLookupProvider.overrideWithValue(
        lyricsLookup ?? FakeLyricsLookup(),
      ),
      ...extraOverrides,
    ],
    child: const StudioApp(),
  );
}
