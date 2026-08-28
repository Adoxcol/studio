import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:studio/core/desktop/desktop_transport.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// System tray, close-to-tray, and media keys. Wired from [main], not tests.
class StudioDesktopHost extends ConsumerStatefulWidget {
  const StudioDesktopHost({super.key, required this.child});

  final Widget child;

  static String get iconAsset => Platform.isWindows
      ? 'assets/tray/app_icon.ico'
      : 'assets/tray/app_icon.png';

  @override
  ConsumerState<StudioDesktopHost> createState() => _StudioDesktopHostState();
}

class _StudioDesktopHostState extends ConsumerState<StudioDesktopHost>
    with WindowListener, TrayListener {
  var _quitting = false;
  var _started = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    unawaited(hotKeyManager.unregisterAll());
    unawaited(trayManager.destroy());
    super.dispose();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    try {
      await windowManager.setPreventClose(true);
    } on Object catch (error, stack) {
      debugPrint('Window close intercept unavailable: $error\n$stack');
    }
    await _registerMediaKeys();
    await _setupTray();
  }

  Future<void> _registerMediaKeys() async {
    try {
      await hotKeyManager.unregisterAll();
      await hotKeyManager.register(
        HotKey(
          identifier: 'studio.playPause',
          key: LogicalKeyboardKey.mediaPlayPause,
        ),
        keyDownHandler: (_) => unawaited(_run(DesktopTransport.playPause)),
      );
      await hotKeyManager.register(
        HotKey(
          identifier: 'studio.next',
          key: LogicalKeyboardKey.mediaTrackNext,
        ),
        keyDownHandler: (_) => unawaited(_run(DesktopTransport.next)),
      );
      await hotKeyManager.register(
        HotKey(
          identifier: 'studio.previous',
          key: LogicalKeyboardKey.mediaTrackPrevious,
        ),
        keyDownHandler: (_) => unawaited(_run(DesktopTransport.previous)),
      );
    } on Object catch (error, stack) {
      debugPrint('Media keys unavailable: $error\n$stack');
    }
  }

  Future<void> _setupTray() async {
    try {
      await trayManager.setIcon(StudioDesktopHost.iconAsset);
      await trayManager.setToolTip('Studio');
      await _refreshTray(ref.read(playbackControllerProvider));
    } on Object catch (error, stack) {
      debugPrint('System tray unavailable: $error\n$stack');
    }
  }

  Future<void> _refreshTray(PlaybackUiState playback) async {
    try {
      await trayManager.setToolTip(
        desktopTrayTooltip(
          hasTrack: playback.trackId != null,
          playing: playback.playing,
          title: playback.title,
          artist: playback.artist,
        ),
      );
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: 'playPause',
              label: desktopPlayPauseLabel(playback.playing),
              disabled: playback.trackId == null,
            ),
            MenuItem(key: 'previous', label: 'Previous'),
            MenuItem(key: 'next', label: 'Next'),
            MenuItem.separator(),
            MenuItem(key: 'show', label: 'Show Studio'),
            MenuItem(key: 'quit', label: 'Quit'),
          ],
        ),
      );
    } on Object catch (error, stack) {
      debugPrint('Tray menu update failed: $error\n$stack');
    }
  }

  Future<void> _run(DesktopTransport action) async {
    final playback = ref.read(playbackControllerProvider.notifier);
    switch (action) {
      case DesktopTransport.playPause:
        await playback.togglePlayPause();
      case DesktopTransport.next:
        await playback.skipNext();
      case DesktopTransport.previous:
        await playback.skipPrevious();
      case DesktopTransport.show:
        await _showWindow();
      case DesktopTransport.quit:
        await _quit();
    }
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.setSkipTaskbar(false);
      await windowManager.show();
      await windowManager.focus();
    } on Object catch (error, stack) {
      debugPrint('Show window failed: $error\n$stack');
    }
  }

  Future<void> _hideToTray() async {
    try {
      await windowManager.hide();
      await windowManager.setSkipTaskbar(true);
    } on Object catch (error, stack) {
      debugPrint('Hide to tray failed: $error\n$stack');
    }
  }

  Future<void> _quit() async {
    if (_quitting) return;
    _quitting = true;
    try {
      await hotKeyManager.unregisterAll();
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } on Object catch (error, stack) {
      debugPrint('Quit failed: $error\n$stack');
    }
  }

  @override
  void onWindowClose() {
    if (_quitting) return;
    unawaited(_hideToTray());
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isWindows) {
      unawaited(_showWindow());
    } else {
      unawaited(trayManager.popUpContextMenu());
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = desktopTransportForMenuKey(menuItem.key);
    if (action != null) unawaited(_run(action));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      playbackControllerProvider.select(
        (s) => (s.trackId, s.playing, s.title, s.artist),
      ),
      (_, _) {
        unawaited(_refreshTray(ref.read(playbackControllerProvider)));
      },
    );
    return widget.child;
  }
}
