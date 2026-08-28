import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/app.dart';
import 'package:studio/core/window/window_bootstrap.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';

Future<void> main() async {
  await bootstrapWindow();
  MediaKit.ensureInitialized();
  final db = await openStudioDatabase();
  runApp(
    ProviderScope(
      overrides: [studioDatabaseProvider.overrideWithValue(db)],
      child: const StudioApp(),
    ),
  );
}
