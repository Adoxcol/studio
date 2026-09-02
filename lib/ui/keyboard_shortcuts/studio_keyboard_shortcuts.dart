import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class StudioKeyboardShortcuts extends ConsumerWidget {
  const StudioKeyboardShortcuts({super.key, required this.child});

  final Widget child;

  bool _editingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorWidgetOfExactType<EditableText>() != null ||
        context?.widget is EditableText;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    void run(VoidCallback action) {
      if (!_editingText()) action();
    }

    void navigate(StudioDestination destination) {
      if (_editingText()) return;
      ref.read(playbackModeProvider.notifier).exit();
      ref.read(studioNavProvider.notifier).select(destination);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            run(controller.togglePlayPause),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause):
            controller.togglePlayPause,
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext):
            controller.skipNext,
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
            controller.skipPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => run(
          () => controller.seekTo(
            playback.position + const Duration(seconds: 10),
          ),
        ),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => run(
          () => controller.seekTo(
            playback.position - const Duration(seconds: 10),
          ),
        ),
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          control: true,
        ): () =>
            run(controller.skipNext),
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          control: true,
        ): () =>
            run(controller.skipPrevious),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            run(() => controller.setVolume(playback.volume + 0.05)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            run(() => controller.setVolume(playback.volume - 0.05)),
        const SingleActivator(LogicalKeyboardKey.keyS): () =>
            run(controller.toggleShuffle),
        const SingleActivator(LogicalKeyboardKey.keyR): () =>
            run(controller.cycleRepeat),
        const SingleActivator(LogicalKeyboardKey.f11): () => run(() {
          final mode = ref.read(playbackModeProvider);
          final notifier = ref.read(playbackModeProvider.notifier);
          mode ? notifier.exit() : notifier.enter();
        }),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            navigate(StudioDestination.library),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            navigate(StudioDestination.nowPlaying),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            navigate(StudioDestination.queue),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () {
          if (!_editingText()) _showShortcutReference(context);
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

Future<void> _showShortcutReference(BuildContext context) {
  const groups = <String, List<(String, String)>>{
    'Playback': [
      ('Space', 'Play / pause'),
      ('← / →', 'Seek 10 seconds'),
      ('Ctrl + ← / →', 'Previous / next track'),
      ('↑ / ↓', 'Volume'),
      ('S', 'Shuffle'),
      ('R', 'Repeat mode'),
      ('F11', 'Playback Mode'),
    ],
    'Navigation': [
      ('Ctrl + 1', 'Library'),
      ('Ctrl + 2', 'Now Playing'),
      ('Ctrl + 3', 'Queue'),
      ('Ctrl + /', 'Shortcut reference'),
    ],
  };
  return showDialog<void>(
    context: context,
    builder: (context) {
      final palette = StudioPalette.of(context);
      return AlertDialog(
        key: const ValueKey('shortcut-reference'),
        backgroundColor: palette.bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: palette.hairline),
        ),
        title: const Text('Keyboard shortcuts'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in groups.entries) ...[
                  Text(
                    group.key.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.inkMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final shortcut in group.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 112,
                            child: Text(
                              shortcut.$1,
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Expanded(child: Text(shortcut.$2)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
