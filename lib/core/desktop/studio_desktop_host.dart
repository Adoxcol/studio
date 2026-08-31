import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/core/desktop/close_preference_provider.dart';
import 'package:studio/core/desktop/close_window_dialog.dart';
import 'package:studio/core/desktop/desktop_transport.dart';
import 'package:studio/discord/discord_presence_controller.dart';
import 'package:studio/discord/discord_settings_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// System tray, close-to-tray, and media keys. Wired from [main], not tests.
class StudioDesktopHost extends ConsumerStatefulWidget {
  const StudioDesktopHost({super.key, required this.child});

  final Widget child;

  static String get iconAsset => Platform.isWindows
      ? 'assets/tray/app_icon.ico'
      : 'assets/tray/app_icon.png';

  static const windowsChannel = MethodChannel('studio/tray');

  @override
  ConsumerState<StudioDesktopHost> createState() => _StudioDesktopHostState();
}

class _StudioDesktopHostState extends ConsumerState<StudioDesktopHost>
    with WindowListener, TrayListener, WidgetsBindingObserver {
  var _quitting = false;
  var _started = false;
  var _trayReady = false;
  var _closePromptOpen = false;
  late final DiscordPresenceController _discord;

  bool get _useWindowsTray => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _discord = DiscordPresenceController(
      client: ref.read(discordRpcClientProvider),
      artwork: ref.read(discordArtworkUploaderProvider),
    );
    WidgetsBinding.instance.addObserver(this);
    if (!_useWindowsTray) {
      trayManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_start());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    if (_useWindowsTray) {
      StudioDesktopHost.windowsChannel.setMethodCallHandler(null);
      unawaited(StudioDesktopHost.windowsChannel.invokeMethod('destroy'));
    } else {
      trayManager.removeListener(this);
      unawaited(trayManager.destroy());
    }
    unawaited(hotKeyManager.unregisterAll());
    unawaited(_discord.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    windowManager.addListener(this);
    try {
      // Swallow WM_CLOSE during startup. A close event here used to Quit
      // and the window vanished as soon as the first frame landed.
      await windowManager.setPreventClose(true);
    } on Object catch (error, stack) {
      debugPrint('Window close intercept unavailable: $error\n$stack');
    }
    await _syncWindowBackground();
    await _setupTray();
    if (!_trayReady) {
      try {
        await windowManager.setPreventClose(false);
      } on Object catch (error, stack) {
        debugPrint('Window close intercept restore failed: $error\n$stack');
      }
    }
    // Windows media keys are RegisterHotKey'd in the runner. hotkey_manager
    // sends a null keyCode for Next/Previous and the plugin then aborts.
    if (!_useWindowsTray) {
      await _registerMediaKeys();
    }
    await _syncDiscord();
  }

  Future<void> _registerMediaKeys() async {
    try {
      await hotKeyManager.unregisterAll();
    } on Object catch (error, stack) {
      debugPrint('Media key reset unavailable: $error\n$stack');
    }
    await _registerMediaKey(
      'studio.playPause',
      PhysicalKeyboardKey.mediaPlayPause,
      DesktopTransport.playPause,
    );
    await _registerMediaKey(
      'studio.next',
      PhysicalKeyboardKey.mediaTrackNext,
      DesktopTransport.next,
    );
    await _registerMediaKey(
      'studio.previous',
      PhysicalKeyboardKey.mediaTrackPrevious,
      DesktopTransport.previous,
    );
  }

  Future<void> _registerMediaKey(
    String identifier,
    PhysicalKeyboardKey key,
    DesktopTransport action,
  ) async {
    try {
      await hotKeyManager.register(
        HotKey(identifier: identifier, key: key),
        keyDownHandler: (_) => unawaited(_run(action)),
      );
    } on Object catch (error, stack) {
      debugPrint('Media key $identifier unavailable: $error\n$stack');
    }
  }

  Future<void> _setupTray() async {
    try {
      if (_useWindowsTray) {
        StudioDesktopHost.windowsChannel.setMethodCallHandler(_onWindowsTray);
        await StudioDesktopHost.windowsChannel.invokeMethod('setIcon');
      } else {
        await trayManager.setIcon(StudioDesktopHost.iconAsset);
      }
      await _refreshTray(ref.read(playbackControllerProvider));
      _trayReady = true;
    } on Object catch (error, stack) {
      debugPrint('System tray unavailable: $error\n$stack');
    }
  }

  Future<dynamic> _onWindowsTray(MethodCall call) async {
    switch (call.method) {
      case 'click':
        unawaited(_showWindow());
      case 'menu':
        final action = desktopTransportForMenuKey(call.arguments as String?);
        if (action != null) unawaited(_run(action));
    }
  }

  Future<void> _refreshTray(PlaybackUiState playback) async {
    try {
      final tooltip = desktopTrayTooltip(
        hasTrack: playback.trackId != null,
        playing: playback.playing,
        title: playback.title,
        artist: playback.artist,
      );
      final items = <Map<String, Object?>>[
        {
          'key': 'playPause',
          'label': desktopPlayPauseLabel(playback.playing),
          'disabled': playback.trackId == null,
        },
        {'key': 'previous', 'label': 'Previous'},
        {'key': 'next', 'label': 'Next'},
        {'type': 'separator'},
        {'key': 'show', 'label': 'Show Studio'},
        {'key': 'quit', 'label': 'Quit'},
      ];
      if (_useWindowsTray) {
        await StudioDesktopHost.windowsChannel.invokeMethod('setToolTip', {
          'toolTip': tooltip,
        });
        await StudioDesktopHost.windowsChannel.invokeMethod('setContextMenu', {
          'items': items,
        });
        return;
      }
      await trayManager.setToolTip(tooltip);
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

  @override
  void didChangePlatformBrightness() {
    unawaited(_syncWindowBackground());
  }

  Future<void> _syncDiscord() async {
    try {
      await _discord.sync(
        enabled: ref.read(discordSettingsProvider).enabled,
        playback: ref.read(playbackControllerProvider),
      );
    } on Object catch (error, stack) {
      debugPrint('Discord RPC sync failed: $error\n$stack');
    }
  }

  Future<void> _syncWindowBackground() async {
    final color = StudioTheme.windowBackground(
      ref.read(appearanceProvider).themeMode,
    );
    try {
      await windowManager.setBackgroundColor(color);
    } on Object catch (error, stack) {
      debugPrint('Window background update failed: $error\n$stack');
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
      ref.read(playbackControllerProvider.notifier).saveSession();
      await _discord.dispose();
      await hotKeyManager.unregisterAll();
      if (_useWindowsTray) {
        await StudioDesktopHost.windowsChannel.invokeMethod('destroy');
      } else {
        await trayManager.destroy();
      }
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } on Object catch (error, stack) {
      debugPrint('Quit failed: $error\n$stack');
    }
  }

  @override
  void onWindowClose() {
    unawaited(_handleClose());
  }

  Future<void> _handleClose() async {
    if (_quitting || _closePromptOpen) return;
    final decision = decideClose(
      trayReady: _trayReady,
      quitting: _quitting,
      preference: ref.read(closePreferenceProvider),
    );
    switch (decision) {
      case CloseDecision.ask:
        await _promptClose();
      case CloseDecision.background:
        await _hideToTray();
      case CloseDecision.quit:
        await _quit();
    }
  }

  Future<void> _promptClose() async {
    final nav = ref.read(studioNavigatorKeyProvider).currentContext;
    if (nav == null || !nav.mounted) {
      await _hideToTray();
      return;
    }
    _closePromptOpen = true;
    try {
      final choice = await showDialog<CloseWindowChoice>(
        context: nav,
        barrierDismissible: true,
        builder: (context) => const CloseWindowDialog(),
      );
      if (choice == null || _quitting) return;
      if (choice.remember) {
        ref.read(closePreferenceProvider.notifier).remember(choice.action);
      }
      switch (choice.action) {
        case CloseAction.background:
          await _hideToTray();
        case CloseAction.quit:
          await _quit();
      }
    } finally {
      _closePromptOpen = false;
    }
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
        (s) => (
          s.trackId,
          s.playing,
          s.title,
          s.artist,
          s.album,
          s.duration,
          s.artworkPath,
        ),
      ),
      (_, _) {
        unawaited(_refreshTray(ref.read(playbackControllerProvider)));
        unawaited(_syncDiscord());
      },
    );
    ref.listen(discordSettingsProvider.select((s) => s.enabled), (_, _) {
      unawaited(_syncDiscord());
    });
    ref.listen(appearanceProvider.select((s) => s.themeMode), (_, _) {
      unawaited(_syncWindowBackground());
    });
    return widget.child;
  }
}
