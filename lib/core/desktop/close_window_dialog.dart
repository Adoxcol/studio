import 'package:flutter/material.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';

class CloseWindowDialog extends StatefulWidget {
  const CloseWindowDialog({super.key});

  @override
  State<CloseWindowDialog> createState() => _CloseWindowDialogState();
}

class _CloseWindowDialogState extends State<CloseWindowDialog> {
  var _remember = false;

  void _choose(CloseAction action) {
    Navigator.pop(
      context,
      CloseWindowChoice(action: action, remember: _remember),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return AlertDialog(
      backgroundColor: palette.bg,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: Text(
        'Close Studio?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quit completely, or keep playback running in the background.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            key: const ValueKey('close-remember'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _remember = !_remember),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _remember,
                    onChanged: (value) {
                      setState(() => _remember = value ?? false);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: palette.inkMuted),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return palette.accent;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: palette.bg,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Don't show again",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        LibraryTextAction(
          key: const ValueKey('close-background'),
          label: 'Run in background',
          onTap: () => _choose(CloseAction.background),
        ),
        LibraryTextAction(
          key: const ValueKey('close-quit'),
          label: 'Close',
          onTap: () => _choose(CloseAction.quit),
          muted: true,
        ),
      ],
    );
  }
}
