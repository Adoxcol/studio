import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Resizes the native window between the full layout and the mini player.
abstract class MiniWindow {
  Future<void> enter({required bool pinned});
  Future<void> setPinned(bool pinned);
  Future<void> exit();
}

class WindowManagerMiniWindow implements MiniWindow {
  static const miniSize = Size(380, 112);
  static const miniMinimum = Size(320, 96);
  static const fullMinimum = Size(900, 600);

  Rect? _restoreBounds;
  var _restoreMaximized = false;

  @override
  Future<void> enter({required bool pinned}) async {
    await _guard(() async {
      _restoreMaximized = await windowManager.isMaximized();
      if (_restoreMaximized) await windowManager.unmaximize();
      _restoreBounds = await windowManager.getBounds();
      await windowManager.setMinimumSize(miniMinimum);
      await windowManager.setSize(miniSize, animate: true);
      await windowManager.setAlwaysOnTop(pinned);
    });
  }

  @override
  Future<void> setPinned(bool pinned) =>
      _guard(() => windowManager.setAlwaysOnTop(pinned));

  @override
  Future<void> exit() async {
    await _guard(() async {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setMinimumSize(fullMinimum);
      final bounds = _restoreBounds;
      if (bounds != null) {
        await windowManager.setBounds(bounds, animate: true);
      }
      if (_restoreMaximized) await windowManager.maximize();
    });
  }

  /// Widget tests and unsupported window managers keep the in-app layout.
  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      debugPrint('Mini player window change unavailable: $error');
    }
  }
}
