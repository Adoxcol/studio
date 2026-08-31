import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/ui/now_playing/player_bar.dart';

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

  Future<void> pumpPlaying(WidgetTester tester, {int tracks = 1}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < tracks; i++) {
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/music/$i.flac',
          title: i == 0 ? 'First' : 'Second',
          artist: const Value('Aria'),
        ),
      );
    }
    final rows = await db.allTracks();
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: rows),
    );
    await tester.pump();
    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('pause toggles the transport icon on the first frame', (
    tester,
  ) async {
    engine.pauseBlock = Completer<void>();
    await pumpPlaying(tester);

    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
    engine.pauseBlock!.complete();
    engine.pauseBlock = null;
    await tester.pump();
  });

  testWidgets('next skip shows the following track', (tester) async {
    await pumpPlaying(tester, tracks: 2);

    await tester.tap(find.byTooltip('Next'));
    await tester.pump();

    expect(engine.lastUri.toString(), contains('1.flac'));
    expect(find.text('Second'), findsWidgets);
  });

  testWidgets('spans the window and keeps transport at the true center', (
    tester,
  ) async {
    await pumpPlaying(tester);

    final bar = tester.getRect(find.byType(PlayerBar));
    final transportCenter = tester.getCenter(find.byTooltip('Pause'));

    expect(bar.left, 0);
    expect(bar.right, tester.view.physicalSize.width);
    expect(transportCenter.dx, closeTo(bar.center.dx, 0.1));
    expect(
      tester.getRect(find.byTooltip('Settings')).bottom,
      lessThanOrEqualTo(bar.top),
    );
  });

  testWidgets('clicking and dragging the scrubber seeks', (tester) async {
    await pumpPlaying(tester);

    final bar = tester.getRect(find.byType(PlayerBar));
    final y = bar.top + PlayerBar.scrubberHeight / 2;
    final press = await tester.startGesture(
      Offset(bar.left + bar.width * 0.5, y),
    );
    await tester.pump();
    expect(engine.lastSeek.inMilliseconds, greaterThan(0));
    final seeks = engine.seekCount;
    await press.up();
    await tester.pump();
    expect(engine.seekCount, seeks);

    await tester.dragFrom(
      Offset(bar.left + bar.width * 0.2, y),
      Offset(bar.width * 0.4, 0),
    );
    await tester.pump();

    expect(
      engine.lastSeek.inMilliseconds,
      closeTo(const Duration(minutes: 3).inMilliseconds * 0.6, 4000),
    );
  });

  testWidgets('scrubber times appear above the bar on hover', (tester) async {
    await pumpPlaying(tester);

    expect(find.text('3:00'), findsNothing);

    final bar = tester.getRect(find.byType(PlayerBar));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(
      location: Offset(bar.left + bar.width * 0.5, bar.top + 10),
    );
    addTearDown(gesture.removePointer);
    await tester.pump();

    expect(find.text('0:00'), findsWidgets);
    expect(find.text('3:00'), findsOneWidget);
  });
}
