import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/command_palette/presentation/command_palette.dart';
import 'package:studio/features/mini_player/presentation/mini_player_providers.dart';
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
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackControllerProvider.notifier);
    // Read at key-press time: watching would rebuild this app-wide widget on
    // every position tick.
    PlaybackUiState playback() => ref.read(playbackControllerProvider);
    void miniPlayer() => ref.read(miniPlayerProvider.notifier).toggle();

    // Typing wins over these: while a text field has focus the key passes
    // through to it (Space types a space, arrows move the caret).
    final typingKeys = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space):
          controller.togglePlayPause,
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          controller.seekTo(playback().position + const Duration(seconds: 5)),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          controller.seekTo(playback().position - const Duration(seconds: 5)),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          controller.setVolume(playback().volume + 0.05),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          controller.setVolume(playback().volume - 0.05),
      const SingleActivator(LogicalKeyboardKey.escape): () {
        if (ref.read(miniPlayerProvider).active) {
          ref.read(miniPlayerProvider.notifier).exit();
        } else if (ref.read(playbackModeProvider)) {
          ref.read(playbackModeProvider.notifier).exit();
        }
      },
      const SingleActivator(
        LogicalKeyboardKey.keyM,
        control: true,
        shift: true,
      ): miniPlayer,
      const SingleActivator(LogicalKeyboardKey.keyM, meta: true, shift: true):
          miniPlayer,
    };
    // Jump-anywhere commands: these work from text fields too.
    final anywhereKeys = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          showCommandPalette(context),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
          showCommandPalette(context),
    };

    KeyEventResult onKey(FocusNode node, KeyEvent event) {
      final keyboard = HardwareKeyboard.instance;
      for (final MapEntry(key: activator, value: action)
          in anywhereKeys.entries) {
        if (activator.accepts(event, keyboard)) {
          action();
          return KeyEventResult.handled;
        }
      }
      for (final MapEntry(key: activator, value: action)
          in typingKeys.entries) {
        if (!activator.accepts(event, keyboard)) continue;
        // Unlike CallbackShortcuts, report the key as unhandled so the text
        // field still receives it.
        if (_editingText()) return KeyEventResult.ignored;
        action();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return Focus(autofocus: true, onKeyEvent: onKey, child: child);
  }
}
