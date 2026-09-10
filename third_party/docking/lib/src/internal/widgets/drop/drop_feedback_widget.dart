import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Keeps the content mounted while smoothly moving/fading the docking target.
@internal
class DropFeedbackWidget extends StatefulWidget {
  const DropFeedbackWidget({Key? key, this.dropPosition, required this.child})
      : super(key: key);
  final Widget child;
  final DropPosition? dropPosition;

  @override
  State<DropFeedbackWidget> createState() => _DropFeedbackWidgetState();
}

class _DropFeedbackWidgetState extends State<DropFeedbackWidget> {
  DropPosition _lastPosition = DropPosition.left;

  @override
  Widget build(BuildContext context) {
    _lastPosition = widget.dropPosition ?? _lastPosition;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(builder: (context, constraints) {
      final horizontal = _lastPosition == DropPosition.left ||
          _lastPosition == DropPosition.right;
      return Stack(fit: StackFit.expand, children: [
        widget.child,
        AnimatedPositioned(
          duration: duration,
          curve: Curves.easeOutCubic,
          left: _lastPosition == DropPosition.right
              ? constraints.maxWidth / 2
              : 0,
          top: _lastPosition == DropPosition.bottom
              ? constraints.maxHeight / 2
              : 0,
          width: horizontal ? constraints.maxWidth / 2 : constraints.maxWidth,
          height:
              horizontal ? constraints.maxHeight : constraints.maxHeight / 2,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: duration,
              opacity: widget.dropPosition == null ? 0 : 1,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                border: Border.all(color: accent.withValues(alpha: 0.65)),
                borderRadius: BorderRadius.circular(4),
              )),
            ),
          ),
        ),
      ]);
    });
  }
}
