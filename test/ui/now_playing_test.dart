import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/ui/visualizer/amplitude_visualizer.dart';

import '../helpers/pump_studio.dart';
import '../playback/fake_audio_engine.dart';

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

  Future<void> pumpNowPlaying(
    WidgetTester tester, {
    List<Track> tracks = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: tracks),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pump();
  }

  testWidgets('hero uses display type and shows an empty Up Next panel', (
    tester,
  ) async {
    await pumpNowPlaying(tester);

    expect(find.text('Not playing'), findsWidgets);
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('Nothing up next.'), findsOneWidget);
    expect(find.byType(AmplitudeVisualizer), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.text('Not playing').first),
      ).textTheme.displayLarge?.fontSize,
      44,
    );
  });

  testWidgets('Up Next lists upcoming queue titles after play starts', (
    tester,
  ) async {
    await db.upsertTrack(
      TracksCompanion.insert(locator: '/music/a.flac', title: 'First'),
    );
    await db.upsertTrack(
      TracksCompanion.insert(locator: '/music/b.flac', title: 'Second'),
    );
    final rows = await db.allTracks();
    await pumpNowPlaying(tester, tracks: rows);

    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pump();

    expect(find.text('now playing'), findsOneWidget);
    expect(find.text('First'), findsWidgets);
    expect(find.text('Second'), findsOneWidget);
  });
}
