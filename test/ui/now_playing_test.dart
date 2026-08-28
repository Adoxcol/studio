import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/lyrics/lrclib_client.dart';
import 'package:studio/theming/studio_palette.dart';
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
    expect(find.text('Queue is empty.'), findsOneWidget);
    expect(find.byType(SpectrumVisualizer), findsOneWidget);
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
    expect(find.text('Second'), findsWidgets);
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
}
