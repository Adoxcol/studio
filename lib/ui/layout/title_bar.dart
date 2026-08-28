import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:studio/theming/studio_palette.dart';

/// 44px custom titlebar. Three hairline dots are the window controls.
class StudioTitleBar extends StatelessWidget {
  const StudioTitleBar({super.key});

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return DragToMoveArea(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.hairline)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _WindowDot(
                  onTap: () {
                    windowManager.close();
                  },
                  tooltip: 'Hide to tray',
                ),
                const SizedBox(width: 8),
                _WindowDot(
                  onTap: () {
                    windowManager.minimize();
                  },
                  tooltip: 'Minimize',
                ),
                const SizedBox(width: 8),
                _WindowDot(
                  onTap: () {
                    windowManager.isMaximized().then((maximized) {
                      if (maximized) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    });
                  },
                  tooltip: 'Maximize',
                ),
                const Spacer(),
                Text(
                  'Studio',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: palette.hairlineStrong,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
