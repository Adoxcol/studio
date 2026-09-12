import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/state/playback_provider.dart';

class StudioKeyboardShortcuts extends ConsumerWidget {
  const StudioKeyboardShortcuts({super.key, required this.child});

  final Widget child;

  bool _editingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;

    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null ||
        context.findAncestorStateOfType<EditableTextState>() != null ||
        context.findAncestorWidgetOfExactType<TextField>() != null ||
        context.findAncestorWidgetOfExactType<TextFormField>() != null ||
        context.findRenderObject() is RenderEditable;
  }

  @override
  Widget build(BuildContext _, WidgetRef ref) {
    final playback = ref.watch(playbackControllerProvider);
    final controller = ref.read(playbackControllerProvider.notifier);

    void run(VoidCallback action) {
      if (!_editingText()) action();
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            run(controller.togglePlayPause),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => run(
          () =>
              controller.seekTo(playback.position + const Duration(seconds: 5)),
        ),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => run(
          () =>
              controller.seekTo(playback.position - const Duration(seconds: 5)),
        ),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            run(() => controller.setVolume(playback.volume + 0.05)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            run(() => controller.setVolume(playback.volume - 0.05)),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_editingText() && ref.read(playbackModeProvider)) {
            ref.read(playbackModeProvider.notifier).exit();
          }
        },
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}
