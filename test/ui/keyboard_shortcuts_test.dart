import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_mode_provider.dart';
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

  testWidgets('removed shortcuts never hijack text editing', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byType(TextField).first);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.byType(TextField).first, findsOneWidget);
  });

  testWidgets(
    'typing spaces and letters in search text field is never intercepted',
    (tester) async {
      await pumpApp(tester);
      final searchField = find.byType(TextField).first;
      await tester.tap(searchField);
      await tester.pump();

      await tester.enterText(searchField, 'radiohead in rainbows');
      await tester.pump();

      final editable = tester.widget<TextField>(searchField);
      expect(editable.controller?.text, 'radiohead in rainbows');
    },
  );

  testWidgets('escape key exits Playback Mode back to windowed shell', (
    tester,
  ) async {
    await pumpApp(tester);
    final shell = tester.element(find.byType(StudioShell));
    final container = ProviderScope.containerOf(shell);

    // Enter playback mode
    container.read(playbackModeProvider.notifier).enter();
    await tester.pumpAndSettle();
    expect(container.read(playbackModeProvider), isTrue);

    // Press Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(container.read(playbackModeProvider), isFalse);
  });
}
