import 'package:docking/src/drag_over_position.dart';
import 'package:docking/src/layout/docking_layout.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:tabbed_view/tabbed_view.dart';

@internal
mixin DraggableConfigMixin {
  DraggableConfig buildDraggableConfig({
    required DragOverPosition dockingDrag,
    required TabData tabData,
  }) {
    final item = tabData.value as DockingItem;
    return DraggableConfig(
      feedback: _DockDragFeedback(name: item.name ?? ''),
      dragAnchorStrategy: childDragAnchorStrategy,
      onDragStarted: () => dockingDrag.enable = true,
      onDragCompleted: () => dockingDrag.enable = false,
      onDraggableCanceled: (_, __) => dockingDrag.enable = false,
      onDragEnd: (_) => dockingDrag.enable = false,
    );
  }
}

class _DockDragFeedback extends StatelessWidget {
  const _DockDragFeedback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(
          scale: 0.96 + 0.04 * value,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
      child: Material(
        elevation: 6,
        color: theme.colorScheme.surface,
        shadowColor: Colors.black.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(name, style: theme.textTheme.bodySmall),
        ),
      ),
    );
  }
}
