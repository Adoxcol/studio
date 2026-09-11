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
    center: true,
    skipTaskbar: false,
    title: 'Studio',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: backgroundColor ?? StudioPalette.light().bg,
  );

  // Apply size/title-bar options first. The show callback is not awaited
  // by window_manager, so raise the window after this returns.
  await windowManager.waitUntilReadyToShow(options);
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
  // Give the OS a frame to process the show before requesting foreground.
  // Without this delay Windows silently ignores SetForegroundWindow when
  // launched from an IDE or terminal that still owns foreground rights.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await windowManager.focus();
}
