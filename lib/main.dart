import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/app.dart';
import 'package:studio/core/window/window_bootstrap.dart';
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/appearance_store.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/playback/playback_settings_store.dart';

Future<void> main() async {
  await bootstrapWindow();
  MediaKit.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final db = StudioDatabase.onFile(File(p.join(support.path, 'studio.sqlite')));
  final artwork = ArtworkStore(Directory(p.join(support.path, 'artwork')));
  final appearance = FileAppearanceStore(
    File(p.join(support.path, 'appearance.json')),
  );
  final playbackSettings = FilePlaybackSettingsStore(
    File(p.join(support.path, 'playback.json')),
  );
  runApp(
    ProviderScope(
      overrides: [
        studioDatabaseProvider.overrideWithValue(db),
        artworkStoreProvider.overrideWithValue(artwork),
        appearanceStoreProvider.overrideWithValue(appearance),
        playbackSettingsStoreProvider.overrideWithValue(playbackSettings),
      ],
      child: const StudioApp(),
    ),
  );
}
