import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Initializes the native window. Widget tests should pump [StudioApp]
/// directly and skip this — window_manager needs a real desktop embedder.
Future<void> bootstrapWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(900, 600),
    title: 'Studio',
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0xFFF9F4EE),
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
