import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/studio_palette.dart';

import 'helpers/pump_studio.dart';
import 'playback/fake_audio_engine.dart';

void main() {
  late StudioDatabase db;
  late FakeAudioEngine engine;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    db = StudioDatabase.memory();
    engine = FakeAudioEngine();
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
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();
  }

  testWidgets('Studio shell shows library placeholder', (tester) async {
    await pumpApp(tester);

    expect(find.text('Library'), findsWidgets);
    expect(find.text('Now Playing'), findsWidgets);
    expect(
      find.text('Library is empty. Local files will show up here.'),
      findsOneWidget,
    );
    expect(find.text('Not playing'), findsWidgets);
    expect(find.byTooltip('Library'), findsOneWidget);
    expect(find.byTooltip('Now Playing'), findsOneWidget);
    expect(find.byTooltip('Queue'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.text('Add folder'), findsOneWidget);
    expect(find.text('Queue'), findsWidgets);
  });

  testWidgets('icon rail opens Settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('light theme uses Editorial Mono background', (tester) async {
    await pumpApp(tester);
    expect(
      Theme.of(
        tester.element(find.text('Library').first),
      ).scaffoldBackgroundColor,
      StudioPalette.light().bg,
    );
  });
}
