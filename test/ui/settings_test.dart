import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

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

  testWidgets('appearance settings switch to a custom teal accent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('Auto — from album art'), findsOneWidget);
    expect(find.text('Custom'), findsWidgets);
    expect(find.text('AUTO · TERRACOTTA'), findsOneWidget);

    await tester.tap(find.byTooltip('Teal'));
    await tester.pumpAndSettle();

    expect(find.text('CUSTOM · TEAL'), findsOneWidget);
    expect(
      StudioPalette.of(tester.element(find.text('CUSTOM · TEAL'))).accent,
      StudioPalette.light(hue: AccentSeed.teal.hue).accent,
    );
  });

  testWidgets('hue slider sets a custom accent between named swatches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('hue-slider')));
    await tester.pump();
    final bar = tester.getRect(find.byKey(const ValueKey('hue-slider')));
    await tester.tapAt(Offset(bar.left + bar.width * 173 / 360, bar.center.dy));
    await tester.pumpAndSettle();

    expect(find.textContaining(RegExp(r'CUSTOM · \d+°')), findsWidgets);
    expect(find.text('CUSTOM · TEAL'), findsNothing);
    expect(find.text('CUSTOM · TERRACOTTA'), findsNothing);
  });

  testWidgets('ReplayGain Album is stored on the engine', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('PLAYBACK & SOUND'), findsOneWidget);
    expect(find.text('ReplayGain'), findsOneWidget);

    await tester.tap(find.text('Album'));
    await tester.pump();

    expect(engine.lastReplayGain, ReplayGainMode.album);
  });

  testWidgets('equalizer Warm preset is stored on the engine', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('Equalizer'), findsOneWidget);
    await tester.ensureVisible(find.text('Warm'));
    await tester.pump();
    await tester.tap(find.text('Warm'));
    await tester.pump();

    expect(engine.lastEqualizer, Equalizer.warm);
  });

  testWidgets('crossfade 5s is stored on the engine', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('Crossfade'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('crossfade-slider')));
    await tester.pump();
    final bar = tester.getRect(find.byKey(const ValueKey('crossfade-slider')));
    await tester.tapAt(Offset(bar.left + bar.width * 5 / 15, bar.center.dy));
    await tester.pump();

    expect(engine.lastCrossfade, Crossfade.fiveSeconds);
  });
}
