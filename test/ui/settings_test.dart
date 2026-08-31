import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/discord/discord_settings_provider.dart';
import 'package:studio/discord/discord_settings_store.dart';
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

  testWidgets('appearance settings switch to dark surfaces', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(
      StudioPalette.of(tester.element(find.text('Settings'))).bg,
      StudioPalette.light().bg,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      StudioPalette.of(tester.element(find.text('Settings'))).bg,
      StudioPalette.dark().bg,
    );
    expect(
      Theme.of(tester.element(find.text('Settings'))).brightness,
      Brightness.dark,
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

  testWidgets('library settings keep layout and cover art options', (
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
    await tester.scrollUntilVisible(
      find.text('Cover art'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('Cover art'), findsOneWidget);
    expect(find.text('Show'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);

    await tester.tap(find.text('Hide'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Missing covers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Missing covers'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
  });

  testWidgets('settings lists configured music folders and offers Add folder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        folders: [const LibraryFolder(id: 1, path: '/music/Records')],
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Music folders'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('/music/Records'), findsOneWidget);
    expect(find.text('Add folder'), findsOneWidget);
  });

  testWidgets(
    'artist downloads can be disabled without disabling cover downloads',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testStudioApp(db: db, engine: engine));
      await tester.pump();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Cached / custom only'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cached / custom only'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.text('Cached / custom only')),
      );
      expect(container.read(appearanceProvider).fetchArtistPictures, isFalse);
      expect(container.read(appearanceProvider).fetchMissingArtwork, isTrue);
      await tester.tap(find.text('Fetch automatically'));
      await tester.pump();
      expect(container.read(appearanceProvider).fetchArtistPictures, isTrue);
      expect(engine.playCount, 0);
    },
  );

  testWidgets('ReplayGain Album is stored on the engine', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('PLAYBACK & SOUND'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('PLAYBACK & SOUND'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Album'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ReplayGain'), findsOneWidget);

    await tester.tap(find.text('Album'));
    await tester.pump();

    expect(engine.lastReplayGain, ReplayGainMode.album);
  });

  testWidgets('equalizer Rock preset is stored on the engine', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Equalizer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Equalizer'), findsOneWidget);
    await tester.ensureVisible(find.text('Rock'));
    await tester.pump();
    await tester.tap(find.text('Rock'));
    await tester.pump();

    expect(engine.lastEqualizer, Equalizer.rock);
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

    await tester.scrollUntilVisible(
      find.text('Crossfade'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Crossfade'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('crossfade-slider')));
    await tester.pump();
    final bar = tester.getRect(find.byKey(const ValueKey('crossfade-slider')));
    await tester.tapAt(Offset(bar.left + bar.width * 5 / 15, bar.center.dy));
    await tester.pump();

    expect(engine.lastCrossfade, Crossfade.fiveSeconds);
  });

  testWidgets('Discord presence can be turned on in settings', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryDiscordSettingsStore();
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        extraOverrides: [discordSettingsStoreProvider.overrideWithValue(store)],
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Show what is playing'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('DISCORD'), findsOneWidget);
    expect(store.load().enabled, isFalse);

    await tester.tap(find.text('On'));
    await tester.pump();
    expect(store.load().enabled, isTrue);
  });
}
