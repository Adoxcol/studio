import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/library_browser/library_page.dart';

import '../helpers/pump_studio.dart';
import '../helpers/tracks.dart';
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

  Future<void> pumpLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        stubPlaylists: false,
        tracks: List.generate(100, (i) {
          final number = i.toString().padLeft(3, '0');
          return testTrack(
            id: i + 1,
            title: 'Track $number',
            artist: 'Artist $number',
            album: 'Album $number',
            genre: 'Genre $number',
          );
        }),
        folders: List.generate(
          100,
          (i) => LibraryFolder(id: i + 1, path: '/music/Folder $i'),
        ),
        extraOverrides: [
          playlistTracksProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
          playlistsProvider.overrideWith(
            (ref) => Stream.value(
              List.generate(
                100,
                (i) => Playlist(
                  id: i + 1,
                  name: 'Playlist $i',
                  createdAt: DateTime.utc(2026),
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(body: LibraryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final back = find.byKey(const ValueKey('library-back'));
  final vertical = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(vertical).position;

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<Finder> scrollToGroup(WidgetTester tester, String prefix) async {
    position(tester).jumpTo(950);
    await tester.pumpAndSettle();
    return find.textContaining(RegExp('^$prefix [0-9]+\$')).hitTestable().first;
  }

  testWidgets('artist Back restores scroll, search, and ordering immediately', (
    tester,
  ) async {
    await pumpLibrary(tester);
    expect(back, findsNothing);
    await openTab(tester, 'Artists');
    await tester.enterText(find.byType(TextField), 'Artist');
    await tester.tap(find.text('Order: A–Z'));
    await tester.pumpAndSettle();

    // Repeat the trip to catch stale/overwritten page-storage entries.
    for (var visit = 0; visit < 2; visit++) {
      final target = await scrollToGroup(tester, 'Artist');
      final name = tester.widget<Text>(target).data!;
      final offset = position(tester).pixels;
      final location = tester.getTopLeft(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to Artists'), findsOneWidget);
      expect(position(tester).pixels, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );

      await tester.enterText(find.byType(TextField), 'unmatched query');
      await tester.tap(find.text('Sort: Title'));
      await tester.tap(find.text('Order: Z–A'));
      await tester.pumpAndSettle();
      await tester.tap(back);
      // Restoration must happen in the first frame, without an animated jump.
      await tester.pump();
      expect(position(tester).pixels, closeTo(offset, 0.01));
      expect(tester.getTopLeft(find.text(name)), location);
      expect(find.text('Sort: Title'), findsOneWidget);
      expect(find.text('Order: Z–A'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Artist',
      );
      expect(back, findsNothing);
    }
    expect(engine.lastUri, isNull);
  });

  testWidgets('album Back restores the section position and original sort', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await openTab(tester, 'Albums');
    final target = await scrollToGroup(tester, 'Album');
    final name = tester.widget<Text>(target).data!;
    final location = tester.getTopLeft(target);
    final offset = position(tester).pixels;
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Sort: Track'), findsOneWidget);
    expect(find.byTooltip('Back to Albums'), findsOneWidget);
    await tester.tap(back);
    await tester.pump();
    expect(position(tester).pixels, closeTo(offset, 0.01));
    expect(tester.getTopLeft(find.text(name)), location);
    expect(find.text('Sort: Title'), findsOneWidget);
    expect(engine.lastUri, isNull);
  });

  testWidgets('an artist opened from Albums returns to Albums, not Artists', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await openTab(tester, 'Albums');
    final target = await scrollToGroup(tester, 'Artist');
    final offset = position(tester).pixels;
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back to Albums'), findsOneWidget);
    await tester.tap(back);
    await tester.pump();
    expect(position(tester).pixels, closeTo(offset, 0.01));
    expect(find.textContaining(RegExp(r'^Album [0-9]+$')), findsWidgets);
    expect(back, findsNothing);
  });

  for (final group in [
    (tab: 'Artists', prefix: 'Artist'),
    (tab: 'Genres', prefix: 'Genre'),
    (tab: 'Playlists', prefix: 'Playlist'),
    (tab: 'Folders', prefix: 'Folder'),
  ]) {
    testWidgets(
      '${group.tab} restores position using Back or the original tab',
      (tester) async {
        await pumpLibrary(tester);
        await openTab(tester, group.tab);
        for (final useTab in [false, true]) {
          final target = await scrollToGroup(tester, group.prefix);
          final name = tester.widget<Text>(target).data!;
          final offset = position(tester).pixels;
          final location = tester.getTopLeft(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(find.byTooltip('Back to ${group.tab}'), findsOneWidget);
          if (useTab) {
            await openTab(tester, group.tab);
          } else {
            await tester.tap(back);
            await tester.pump();
          }
          expect(position(tester).pixels, closeTo(offset, 0.01));
          expect(tester.getTopLeft(find.text(name)), location);
          expect(back, findsNothing);
        }
        expect(engine.lastUri, isNull);
      },
    );
  }

  testWidgets(
    'the final track can scroll clear of floating Back in both layouts',
    (tester) async {
      await pumpLibrary(tester);
      await openTab(tester, 'Folders');
      await tester.tap(find.text('Folder 0'));
      await tester.pumpAndSettle();
      for (final layout in ['Cards', 'List']) {
        expect(find.text('View: $layout'), findsOneWidget);
        position(tester).jumpTo(position(tester).maxScrollExtent);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(find.text('Track 099')).dy,
          lessThan(tester.getTopLeft(back).dy),
        );
        if (layout == 'Cards') {
          await tester.tap(find.text('View: Cards'));
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets('choosing an unrelated tab clears drill-down history', (
    tester,
  ) async {
    await pumpLibrary(tester);
    await openTab(tester, 'Artists');
    await tester.tap(find.text('Artist 000'));
    await tester.pumpAndSettle();
    expect(back, findsOneWidget);
    await openTab(tester, 'Genres');
    expect(back, findsNothing);
    expect(find.text('100 GENRES'), findsOneWidget);
    expect(position(tester).pixels, 0);
  });
}
