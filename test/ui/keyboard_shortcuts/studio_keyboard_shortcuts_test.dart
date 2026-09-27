import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/ui/keyboard_shortcuts/studio_keyboard_shortcuts.dart';

class _FakePlayback extends PlaybackController {
  final seeks = <Duration>[];
  final volumes = <double>[];
  var toggles = 0;

  @override
  PlaybackUiState build() => const PlaybackUiState(volume: 0.5);

  void tick(Duration position) => state = state.copyWith(position: position);

  @override
  Future<void> togglePlayPause() async => toggles++;

  @override
  Future<void> seekTo(Duration position) async => seeks.add(position);

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);
}

void main() {
  late _FakePlayback playback;

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    playback = _FakePlayback();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playbackControllerProvider.overrideWith(() => playback)],
        child: MaterialApp(
          home: Scaffold(
            body: StudioKeyboardShortcuts(
              child: child ?? const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Space toggles playback outside text fields', (tester) async {
    await pump(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(playback.toggles, 1);
  });

  testWidgets('Space types into a focused search field', (tester) async {
    final text = TextEditingController();
    addTearDown(text.dispose);
    await pump(tester, child: TextField(controller: text));

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'daft');
    // Unhandled means the key goes on to the text input and types a space;
    // the bug was the shortcut layer marking it handled and swallowing it.
    final handled = await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(handled, isFalse);
    expect(playback.toggles, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(playback.seeks, isEmpty);
  });

  testWidgets('arrow keys seek from the latest position', (tester) async {
    await pump(tester);

    playback.tick(const Duration(seconds: 30));
    await tester.pump();
    playback.tick(const Duration(seconds: 42));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);

    expect(playback.seeks, const [
      Duration(seconds: 47),
      Duration(seconds: 37),
    ]);
    expect(playback.volumes.single, closeTo(0.55, 1e-9));
  });
}
