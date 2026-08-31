import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/layout/studio_shell.dart';

class StudioApp extends ConsumerWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hue = ref.watch(resolvedAccentHueProvider);
    return MaterialApp(
      title: 'Studio',
      debugShowCheckedModeBanner: false,
      theme: StudioTheme.light(hue: hue),
      darkTheme: StudioTheme.dark(hue: hue),
      themeMode: StudioTheme.materialMode(
        ref.watch(appearanceProvider).themeMode,
      ),
      navigatorKey: ref.watch(studioNavigatorKeyProvider),
      home: const StudioShell(),
    );
  }
}
