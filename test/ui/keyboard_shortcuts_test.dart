import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/ui/layout/studio_shell.dart';

import '../helpers/pump_studio.dart';
import '../playback/fake_audio_engine.dart';

void main() {
  late StudioDatabase db;
  late FakeAudioEngine engine;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    db = StudioDatabase.memory();
    engine = FakeAudioEngine();
  });

  tearDown(() async {
    await db.close();
    engine.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();
  }

  Future<void> pressControlShortcut(
    WidgetTester tester,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('navigation shortcuts work but never hijack text editing', (
    tester,
  ) async {
    await pumpApp(tester);
    final shell = tester.element(find.byType(StudioShell));
    final container = ProviderScope.containerOf(shell);

    await pressControlShortcut(tester, LogicalKeyboardKey.digit3);
    expect(container.read(studioNavProvider), StudioDestination.queue);

    await pressControlShortcut(tester, LogicalKeyboardKey.digit1);
    expect(container.read(studioNavProvider), StudioDestination.library);

    await tester.tap(find.byType(TextField).first);
    await pressControlShortcut(tester, LogicalKeyboardKey.digit3);
    expect(container.read(studioNavProvider), StudioDestination.library);
  });

  testWidgets('shortcut reference is available from the keyboard', (
    tester,
  ) async {
    await pumpApp(tester);

    await pressControlShortcut(tester, LogicalKeyboardKey.slash);

    expect(find.byKey(const ValueKey('shortcut-reference')), findsOneWidget);
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Play / pause'), findsOneWidget);
    expect(find.text('Ctrl + 3'), findsOneWidget);
  });
}
