import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scan_progress.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/appearance_store.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

import '../helpers/pump_studio.dart';
import '../helpers/tracks.dart';
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

  Future<void> pumpLibrary(
    WidgetTester tester, {
    List<Track> tracks = const [],
    List<LibraryFolder> folders = const [],
    List extraOverrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: tracks,
        folders: folders,
        extraOverrides: extraOverrides,
      ),
    );
    await tester.pump();
  }

  testWidgets('library chrome matches the All view', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('Library'), findsWidgets);
    expect(find.text('Search your library'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Genres'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Recently Added'), findsNothing);
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Sort: Title'), findsOneWidget);
    expect(find.text('Order: A–Z'), findsOneWidget);
    expect(find.text('View: Cards'), findsOneWidget);
    expect(find.text('ARTISTS'), findsNothing);
    expect(find.text('LIBRARY'), findsNothing);
    expect(find.text('Add folder'), findsNothing);
    expect(find.byTooltip('Rescan library'), findsOneWidget);
  });

  testWidgets('track rows show artwork, artists, and switchable columns', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      tracks: [
        testTrack(id: 1, durationMs: 238000),
        testTrack(
          id: 2,
          title: 'Glass Harbor',
          artist: 'Halvard Iyer',
          album: 'Nightlight',
          durationMs: 192000,
        ),
      ],
    );

    expect(find.text('TITLE'), findsNothing);
    expect(find.text('ARTIST'), findsNothing);
    expect(find.text('ALBUM'), findsNothing);
    expect(find.text('TIME'), findsNothing);
    expect(find.text('Nocturne in Blue'), findsOneWidget);
    expect(find.text('Afterglow'), findsOneWidget);
    expect(find.text('Aria Solvang'), findsWidgets);
    expect(find.text('Halvard Iyer'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CoverArt && widget.size == 56,
      ),
      findsNWidgets(2),
    );

    await tester.tap(find.text('View: Cards'));
    await tester.pump();
    expect(find.text('View: List'), findsOneWidget);
    expect(find.text('TITLE'), findsOneWidget);
    expect(find.text('3:58'), findsOneWidget);
  });

  testWidgets('hiding cover art removes thumbnails from track cards', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      tracks: [testTrack()],
      extraOverrides: [
        appearanceStoreProvider.overrideWithValue(
          MemoryAppearanceStore(const AppearanceState(showTrackArtwork: false)),
        ),
      ],
    );

    expect(find.text('Nocturne in Blue'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CoverArt && widget.size == 56,
      ),
      findsNothing,
    );
  });

  testWidgets('featured tracks appear in that artist catalog', (tester) async {
    await pumpLibrary(
      tester,
      tracks: [
        testTrack(
          id: 1,
          title: 'Rich Flex',
          artist: '21 Savage, Offset',
          album: 'Her Loss',
        ),
        testTrack(
          id: 2,
          title: 'Jimmy Cooks',
          artist: 'Drake feat. 21 Savage',
          album: 'Honestly, Nevermind',
        ),
      ],
    );

    expect(find.text('21 Savage, Offset'), findsOneWidget);
    expect(find.text('Drake feat. 21 Savage'), findsOneWidget);
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(find.text('Offset'), findsWidgets);
    expect(find.text('Drake'), findsWidgets);
    await tester.tap(find.text('21 Savage').first);
    await tester.pump();
    expect(find.text('Rich Flex'), findsOneWidget);
    expect(find.text('Jimmy Cooks'), findsOneWidget);
  });

  testWidgets('search narrows the track list', (tester) async {
    await pumpLibrary(
      tester,
      tracks: [
        testTrack(id: 1),
        testTrack(
          id: 2,
          title: 'Glass Harbor',
          artist: 'Halvard Iyer',
          album: 'Nightlight',
        ),
      ],
    );

    await tester.enterText(find.byType(TextField), 'nocturne');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'harbor');
    await tester.pump(const Duration(milliseconds: 100));
    // A superseded search must not run during rapid typing.
    expect(find.text('Nocturne in Blue'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Glass Harbor'), findsOneWidget);
    expect(find.text('Nocturne in Blue'), findsNothing);
  });

  testWidgets('Artists tab lists artist names', (tester) async {
    await pumpLibrary(tester, tracks: [testTrack()]);

    await tester.ensureVisible(find.text('Artists'));
    await tester.pump();
    await tester.tap(find.text('Artists'));
    await tester.pump();

    expect(find.text('1 ARTIST'), findsOneWidget);
    expect(find.text('1 album'), findsOneWidget);
  });

  testWidgets('opening an album sorts by track number', (tester) async {
    await pumpLibrary(
      tester,
      tracks: [
        testTrack(id: 1, title: 'zebra', trackNumber: 2),
        testTrack(id: 2, title: 'alpha', trackNumber: 1),
      ],
    );

    await tester.ensureVisible(find.text('Albums'));
    await tester.pump();
    await tester.tap(find.text('Albums'));
    await tester.pump();
    await tester.tap(find.text('Afterglow'));
    await tester.pump();

    expect(find.text('Sort: Track'), findsOneWidget);
    // The wider sidebar-free browser fits multiple cards per row. Check the
    // vertical ordering in list mode rather than assuming a one-column grid.
    await tester.tap(find.text('View: Cards'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('alpha')).dy,
      lessThan(tester.getTopLeft(find.text('zebra')).dy),
    );
  });

  testWidgets('Playlists tab is an empty placeholder', (tester) async {
    await pumpLibrary(tester, tracks: [testTrack()]);

    await tester.ensureVisible(find.text('Playlists'));
    await tester.pump();
    await tester.tap(find.text('Playlists'));
    await tester.pump();

    expect(find.text('No playlists yet.'), findsOneWidget);
    expect(find.text('New playlist'), findsOneWidget);
  });

  testWidgets('tapping a row starts playback', (tester) async {
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/a.flac',
        title: 'Nocturne in Blue',
        artist: const Value('Aria Solvang'),
        album: const Value('Afterglow'),
        durationMs: const Value(238000),
      ),
    );
    final rows = await db.allTracks();
    await pumpLibrary(tester, tracks: rows);

    await tester.tap(find.text('Nocturne in Blue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(engine.lastUri, isA<Uri>());
    expect(engine.lastUri!.scheme, 'file');
  });

  testWidgets('Folders tab lists folders with add and remove actions', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      folders: [const LibraryFolder(id: 1, path: '/music/Records')],
    );

    await tester.ensureVisible(find.text('Folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folders'));
    await tester.pumpAndSettle();
    expect(find.text('Music folders'), findsOneWidget);
    expect(find.text('Add folder'), findsOneWidget);
    expect(find.text('Play All'), findsNothing);
    expect(find.text('Records'), findsOneWidget);
    expect(find.byTooltip('Remove folder'), findsOneWidget);
  });

  testWidgets('a folder opens only its tracks and All clears that selection', (
    tester,
  ) async {
    await pumpLibrary(
      tester,
      folders: [
        const LibraryFolder(id: 1, path: '/music/Records'),
        const LibraryFolder(id: 2, path: '/music/Other'),
      ],
      tracks: [
        testTrack(title: 'Inside'),
        testTrack(id: 2, title: 'Outside').copyWith(folderId: const Value(2)),
      ],
    );
    await tester.ensureVisible(find.text('Folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Records'));
    await tester.pumpAndSettle();
    expect(find.text('Inside'), findsOneWidget);
    expect(find.text('Outside'), findsNothing);
    await tester.tap(find.text('All folders'));
    await tester.pumpAndSettle();
    expect(find.text('Records'), findsOneWidget);
    await tester.ensureVisible(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Outside'), findsOneWidget);
  });

  testWidgets('scan notice shows progress and stop', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        extraOverrides: [
          libraryScanProvider.overrideWith(_BusyScan.new),
          libraryBootstrapProvider.overrideWith((ref) async {}),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Scanning'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('4 of 20 files'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });
}

class _BusyScan extends LibraryScanNotifier {
  @override
  ScanProgress build() {
    return const ScanProgress(
      active: true,
      folderLabel: 'Records',
      processed: 4,
      total: 20,
    );
  }
}
