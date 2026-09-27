import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/mini_player/data/mini_player_store.dart';
import 'package:studio/features/mini_player/data/mini_window.dart';
import 'package:studio/features/mini_player/presentation/mini_player_providers.dart';
import 'package:studio/features/mini_player/presentation/mini_player_view.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_mode_provider.dart';

import '../../helpers/pump_studio.dart';
import '../../playback/fake_audio_engine.dart';

class FakeMiniWindow implements MiniWindow {
  final calls = <String>[];

  @override
  Future<void> enter({required bool pinned}) async =>
      calls.add('enter pinned=$pinned');

  @override
  Future<void> exit() async => calls.add('exit');

  @override
  Future<void> setPinned(bool pinned) async => calls.add('pin=$pinned');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('MiniPlayerNotifier', () {
    late FakeMiniWindow window;
    late MemoryMiniPlayerStore store;
    late ProviderContainer container;

    setUp(() {
      window = FakeMiniWindow();
      store = MemoryMiniPlayerStore();
      container = ProviderContainer(
        overrides: [
          miniWindowProvider.overrideWithValue(window),
          miniPlayerStoreProvider.overrideWithValue(store),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('enters and exits once, leaving Playback Mode first', () async {
      container.read(playbackModeProvider.notifier).enter();
      final notifier = container.read(miniPlayerProvider.notifier);
      await notifier.enter();
      await notifier.enter();
      expect(container.read(miniPlayerProvider).active, isTrue);
      expect(container.read(playbackModeProvider), isFalse);
      await notifier.toggle();
      await notifier.exit();
      expect(container.read(miniPlayerProvider).active, isFalse);
      expect(window.calls, ['enter pinned=true', 'exit']);
    });

    test('pinning is saved and applied only while mini', () async {
      final notifier = container.read(miniPlayerProvider.notifier);
      await notifier.togglePinned();
      expect(store.pinned, isFalse);
      expect(window.calls, isEmpty);
      await notifier.enter();
      await notifier.togglePinned();
      expect(window.calls, ['enter pinned=false', 'pin=true']);
      expect(store.pinned, isTrue);
    });
  });

  test('file store remembers the pin and defaults to pinned', () {
    final dir = Directory.systemTemp.createTempSync('studio-mini');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'mini.json'));
    final store = FileMiniPlayerStore(file);
    expect(store.loadPinned(), isTrue);
    store.savePinned(false);
    expect(FileMiniPlayerStore(file).loadPinned(), isFalse);
    file.writeAsStringSync('garbage');
    expect(store.loadPinned(), isTrue);
  });

  group('in the app', () {
    late StudioDatabase db;
    late FakeAudioEngine engine;
    late FakeMiniWindow window;

    setUp(() {
      db = StudioDatabase.memory();
      engine = FakeAudioEngine();
      window = FakeMiniWindow();
    });
    tearDown(() async {
      await db.close();
      engine.dispose();
    });

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        testStudioApp(
          db: db,
          engine: engine,
          extraOverrides: [
            miniWindowProvider.overrideWithValue(window),
            miniPlayerStoreProvider.overrideWithValue(MemoryMiniPlayerStore()),
          ],
        ),
      );
      await tester.pump();
    }

    testWidgets('the player bar button shrinks to the mini player and back', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Mini player'));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayerView), findsOneWidget);
      expect(find.byTooltip('Mini player'), findsNothing);
      expect(find.text('Not playing'), findsOneWidget);

      await tester.tap(find.byTooltip('Stop keeping on top'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Keep on top'), findsOneWidget);

      await tester.tap(find.byTooltip('Back to full player'));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayerView), findsNothing);
      expect(find.byTooltip('Mini player'), findsOneWidget);
      expect(window.calls, ['enter pinned=true', 'pin=false', 'exit']);
    });

    testWidgets('Ctrl+Shift+M toggles and Escape leaves the mini player', (
      tester,
    ) async {
      await pumpApp(tester);
      Future<void> chord() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await chord();
      expect(find.byType(MiniPlayerView), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayerView), findsNothing);
      await chord();
      await chord();
      expect(find.byType(MiniPlayerView), findsNothing);
    });
  });
}
