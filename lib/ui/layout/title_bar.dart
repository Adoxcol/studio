import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:window_manager/window_manager.dart';

/// 44px custom title bar with Windows-style controls on the trailing edge.
class StudioTitleBar extends StatelessWidget {
  const StudioTitleBar({super.key});

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.hairline)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DragToMoveArea(child: SizedBox.expand()),
            Center(
              child: IgnorePointer(
                child: Text(
                  'Studio',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WindowControl(
                    icon: Icons.remove_rounded,
                    tooltip: 'Minimize',
                    onTap: windowManager.minimize,
                  ),
                  _WindowControl(
                    icon: Icons.crop_square_rounded,
                    tooltip: 'Maximize or restore',
                    onTap: () async {
                      if (await windowManager.isMaximized()) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  _WindowControl(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    close: true,
                    onTap: windowManager.close,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowControl extends StatefulWidget {
  const _WindowControl({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.close = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool close;

  @override
  State<_WindowControl> createState() => _WindowControlState();
}

class _WindowControlState extends State<_WindowControl> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final closeHover = widget.close && _hovered;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 46,
            height: StudioTitleBar.height,
            color: closeHover
                ? const Color(0xFFC42B1C)
                : _hovered
                ? palette.hairlineSoft
                : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.close ? 18 : 16,
              color: closeHover ? Colors.white : palette.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
