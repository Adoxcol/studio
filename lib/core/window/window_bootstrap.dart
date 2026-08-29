import 'dart:io';

import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:window_manager/window_manager.dart';

/// Initializes the native window. Widget tests should pump [StudioApp]
/// directly and skip this — window_manager needs a real desktop embedder.
Future<void> bootstrapWindow({Color? backgroundColor}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final options = WindowOptions(
    size: const Size(1280, 800),
    minimumSize: const Size(900, 600),
    title: 'Studio',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: backgroundColor ?? StudioPalette.light().bg,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    try {
      await windowManager.setIcon(
        Platform.isWindows
            ? 'assets/tray/app_icon.ico'
            : 'assets/tray/app_icon.png',
      );
    } on Object catch (error, stack) {
      debugPrint('Window icon update failed: $error\n$stack');
    }
    await windowManager.show();
    await windowManager.focus();
  });
}
