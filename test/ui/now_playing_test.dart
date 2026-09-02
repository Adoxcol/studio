import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/now_playing/player_bar.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/visualizer/spectrum_visualizer.dart';

import '../helpers/pump_studio.dart';
import '../lyrics/fake_lyrics_lookup.dart';
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
    double width = 1400,
  }) async {
    tester.view.physicalSize = Size(width, 900);
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

  testWidgets('hero uses display type beside the dedicated Queue panel', (
    tester,
  ) async {
    await pumpNowPlaying(tester);

    expect(find.text('Not playing'), findsWidgets);
    expect(find.text('Queue is empty.'), findsOneWidget);
    expect(find.byType(SpectrumVisualizer), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.text('Not playing').first),
      ).textTheme.displayLarge?.fontSize,
      44,
    );
  });

  testWidgets('regular Now Playing never adds an Up Next sidebar', (
    tester,
  ) async {
    await pumpNowPlaying(tester, width: 2400);

    expect(
      tester.getSize(find.byType(NowPlayingPage)).width,
      greaterThanOrEqualTo(800),
    );
    expect(find.text('UP NEXT'), findsNothing);
  });

  testWidgets('Playback Mode replaces the Studio shell and exits cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    expect(find.byType(PlayerBar), findsOneWidget);
    await tester.tap(find.byTooltip('Enter Playback Mode'));
    await tester.pump();

    expect(find.byType(PlaybackModePage), findsOneWidget);
    expect(find.byTooltip('Customize Full Player'), findsOneWidget);
    expect(find.byType(NowPlayingPage), findsNothing);
    expect(find.byType(PlayerBar), findsNothing);

    await tester.tap(find.byIcon(Icons.fullscreen_exit));
    await tester.pump();
    expect(find.byType(PlaybackModePage), findsNothing);
    expect(find.byType(PlayerBar), findsOneWidget);
  });

  testWidgets('player-bar artwork opens fullscreen Playback Mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();

    expect(find.bySemanticsLabel('Open Playback Mode'), findsOneWidget);
    await tester.tap(find.byTooltip('Open Playback Mode'));
    await tester.pump();

    expect(find.byType(PlaybackModePage), findsOneWidget);
    expect(find.byType(PlayerBar), findsNothing);
  });

  testWidgets('Playback Mode adapts without overflow at desktop extremes', (
    tester,
  ) async {
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/responsive.flac',
        title: 'Responsive Playback',
        artist: const Value('Studio Artist'),
        album: const Value('Studio Album'),
      ),
    );
    final rows = await db.allTracks();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: rows),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.tap(find.text('Responsive Playback'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Enter Playback Mode'));
    await tester.pump();

    for (final size in const <Size>[
      Size(620, 900),
      Size(2200, 900),
      Size(1200, 480),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(find.byType(PlaybackModePage), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Playback Mode at $size');
    }
  });

  testWidgets('Playback Mode offers all permanent background choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testStudioApp(db: db, engine: engine));
    await tester.pump();
    await tester.tap(find.byTooltip('Enter Playback Mode'));
    await tester.pump();
    await tester.tap(find.byTooltip('Customize Full Player'));
    await tester.pump();

    expect(find.text('Studio gradient'), findsOneWidget);
    expect(find.text('Album artwork'), findsOneWidget);
    expect(find.text('Artist image'), findsOneWidget);
    expect(find.text('Solid color'), findsOneWidget);
  });

  testWidgets('Now Playing does not load the queue track map', (tester) async {
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        extraOverrides: [
          libraryTracksByIdProvider.overrideWith((ref) {
            throw StateError('The Now Playing hero must not load queue tracks');
          }),
        ],
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(body: NowPlayingPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Not playing'), findsOneWidget);
    expect(find.text('UP NEXT'), findsNothing);
  });

  testWidgets('hero lyrics highlight the current line in accent', (
    tester,
  ) async {
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'First',
        artist: const Value('Aria'),
      ),
    );
    final rows = await db.allTracks();
    final lookup = FakeLyricsLookup(
      const LyricsLookupResult(
        LyricsLookupStatus.found,
        LrclibRecord(syncedLyrics: '[00:00.00] Opening\n[00:05.00] Chorus'),
      ),
    );

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: rows, lyricsLookup: lookup),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('Chorus'), findsOneWidget);
    final palette = StudioPalette.of(tester.element(find.text('Opening')));
    expect(
      tester.widget<Text>(find.text('Opening')).style?.color,
      palette.accent,
    );
    expect(
      tester.widget<Text>(find.text('Chorus')).style?.color,
      palette.inkMuted,
    );

    await engine.seek(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.widget<Text>(find.text('Chorus')).style?.color,
      palette.accent,
    );
  });

  testWidgets('tapping a synced lyric seeks to that line', (tester) async {
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'First',
        artist: const Value('Aria'),
      ),
    );
    final rows = await db.allTracks();
    final lookup = FakeLyricsLookup(
      const LyricsLookupResult(
        LyricsLookupStatus.found,
        LrclibRecord(syncedLyrics: '[00:00.00] Opening\n[00:05.00] Chorus'),
      ),
    );

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: rows, lyricsLookup: lookup),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Chorus'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('lyric-1')));
    await tester.pump();
    expect(engine.lastSeek, const Duration(seconds: 5));
  });

  testWidgets('hero fits a short pane with a long title', (tester) async {
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: '(Do the) Act Like You Never Met Me',
        artist: const Value('Aria'),
      ),
    );
    final rows = await db.allTracks();
    tester.view.physicalSize = const Size(1400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: rows),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.tap(find.text('(Do the) Act Like You Never Met Me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pump();

    expect(find.text('now playing'), findsOneWidget);
    expect(find.text('(Do the) Act Like You Never Met Me'), findsWidgets);
  });

  testWidgets('each credited artist opens their individual library catalogue', (
    tester,
  ) async {
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/heat-waves.flac',
        title: 'Heat Waves',
        artist: const Value(
          'Pop Goes Ambient, Vancouver Sleep Clinic & Amelia Magdalena',
        ),
      ),
    );
    final rows = await db.allTracks();
    await pumpNowPlaying(tester, tracks: rows);

    await tester.tap(find.byTooltip('Library'));
    await tester.pump();
    await tester.tap(find.text('Heat Waves'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('now-playing-artist-Pop Goes Ambient')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('now-playing-artist-Vancouver Sleep Clinic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('now-playing-artist-Amelia Magdalena')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('now-playing-artist-Vancouver Sleep Clinic')),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byTooltip('Library')),
    );
    expect(container.read(studioNavProvider), StudioDestination.library);
    expect(
      container.read(libraryNavigationProvider).artist,
      'Vancouver Sleep Clinic',
    );
    expect(find.text('Vancouver Sleep Clinic'), findsWidgets);
    expect(find.text('Heat Waves'), findsWidgets);
  });
}
