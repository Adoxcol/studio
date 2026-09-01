import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:tabbed_view/src/draggable_data.dart';
import 'package:tabbed_view/src/internal/tabbed_view_provider.dart';
import 'package:tabbed_view/src/theme/theme_widget.dart';

@internal
class DropTabWidget extends StatelessWidget {
  const DropTabWidget({
    super.key,
    required this.provider,
    required this.newIndex,
    required this.child,
  });

  final TabbedViewProvider provider;
  final Widget child;
  final int newIndex;
  static const double dropWidth = 8;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DraggableData>(
      onWillAcceptWithDetails: (details) {
        if (newIndex < provider.controller.length) {
          final target = provider.controller.tabs[newIndex];
          if (identical(target, details.data.tabData) ||
              (target.value != null &&
                  identical(target.value, details.data.tabData.value))) {
            return false;
          }
        }
        return provider.canDrop?.call(details.data, provider.controller) ??
            true;
      },
      builder: (context, accepted, rejected) {
        final color = TabbedViewTheme.of(context).tabsArea.dropColor;
        // Stable wrapper: entering/leaving must not replace the tab's draggable.
        // Candidate state also clears correctly for cross-strip/cancelled drags.
        return TweenAnimationBuilder<double>(
          tween: Tween(end: accepted.isEmpty ? 0 : 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 100),
          builder: (context, value, child) => CustomPaint(
            foregroundPainter:
                _InsertionPainter(color.withValues(alpha: value)),
            child: child,
          ),
          child: child,
        );
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (provider.onBeforeDropAccept
                ?.call(data, provider.controller, newIndex) ==
            false) {
          return;
        }
        if (provider.controller == data.controller) {
          provider.controller.reorderTab(data.tabData.index, newIndex);
        } else {
          data.controller.removeTab(data.tabData.index);
          provider.controller.insertTab(newIndex, data.tabData);
        }
      },
    );
  }
}

class _InsertionPainter extends CustomPainter {
  const _InsertionPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 2, 3, (size.height - 4).clamp(0, double.infinity)),
        const Radius.circular(1.5),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _InsertionPainter oldDelegate) =>
      color != oldDelegate.color;
}
