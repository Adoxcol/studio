import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/desktop/close_preference_provider.dart';
import 'package:studio/features/listening_stats/presentation/listening_stats_providers.dart';
import 'package:studio/features/scrobbling/presentation/scrobble_providers.dart';
import 'package:studio/features/skins/presentation/skins_provider.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/layout/studio_shell.dart';

class StudioApp extends ConsumerWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(scrobbleBridgeProvider);
    ref.watch(playHistoryRecorderProvider);
    final hue = ref.watch(resolvedAccentHueProvider);
    final skin = ref.watch(activeSkinProvider);
    return MaterialApp(
      title: 'Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.light(hue: hue, skin: skin?.light),
      darkTheme: StudioTheme.dark(hue: hue, skin: skin?.dark),
      themeMode: StudioTheme.materialMode(
        ref.watch(appearanceProvider).themeMode,
      ),
      navigatorKey: ref.watch(studioNavigatorKeyProvider),
      home: const StudioShell(),
    );
  }
}
