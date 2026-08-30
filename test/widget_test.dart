import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/layout/title_bar.dart';

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
    expect(find.text('Add folder'), findsNothing);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Queue'), findsWidgets);
  });

  testWidgets('icon rail opens Settings', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('title bar uses recognizable controls on the right', (
    tester,
  ) async {
    await pumpApp(tester);

    final titleBar = find.byType(StudioTitleBar);
    final minimize = find.byTooltip('Minimize');
    final maximize = find.byTooltip('Maximize or restore');
    final close = find.byTooltip('Close');
    final titleBarCenter = tester.getCenter(titleBar);

    expect(minimize, findsOneWidget);
    expect(maximize, findsOneWidget);
    expect(close, findsOneWidget);
    expect(tester.getCenter(minimize).dx, greaterThan(titleBarCenter.dx));
    expect(
      tester.getCenter(minimize).dx,
      lessThan(tester.getCenter(maximize).dx),
    );
    expect(tester.getCenter(maximize).dx, lessThan(tester.getCenter(close).dx));
    expect(
      tester.getCenter(find.text('Studio')).dx,
      closeTo(titleBarCenter.dx, 0.1),
    );
    expect(
      find.descendant(
        of: titleBar,
        matching: find.byIcon(Icons.remove_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: titleBar,
        matching: find.byIcon(Icons.crop_square_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: titleBar, matching: find.byIcon(Icons.close_rounded)),
      findsOneWidget,
    );
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
