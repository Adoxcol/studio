import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';

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
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: tracks),
    );
    await tester.pump();
  }

  testWidgets('library chrome matches the All view', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search your library'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Artists'), findsOneWidget);
    expect(find.text('Albums'), findsOneWidget);
    expect(find.text('Genres'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('Play All'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Sort: Title'), findsOneWidget);
    expect(find.text('Order: A–Z'), findsOneWidget);
    expect(find.text('ARTISTS'), findsOneWidget);
    expect(find.text('Add folder'), findsOneWidget);
  });

  testWidgets('track rows show columns, time, and sidebar artists', (
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

    expect(find.text('TITLE'), findsOneWidget);
    expect(find.text('ARTIST'), findsOneWidget);
    expect(find.text('ALBUM'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('Nocturne in Blue'), findsOneWidget);
    expect(find.text('3:58'), findsOneWidget);
    expect(find.text('Aria Solvang'), findsWidgets);
    expect(find.text('Halvard Iyer'), findsWidgets);
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

    await tester.enterText(find.byType(TextField), 'harbor');
    await tester.pump();

    expect(find.text('Glass Harbor'), findsOneWidget);
    expect(find.text('Nocturne in Blue'), findsNothing);
  });

  testWidgets('Artists tab lists artist names', (tester) async {
    await pumpLibrary(tester, tracks: [testTrack()]);

    await tester.tap(find.text('Artists'));
    await tester.pump();

    expect(find.text('1 ARTIST'), findsOneWidget);
    expect(find.text('1 album'), findsOneWidget);
  });

  testWidgets('Playlists tab is an empty placeholder', (tester) async {
    await pumpLibrary(tester, tracks: [testTrack()]);

    await tester.tap(find.text('Playlists'));
    await tester.pump();

    expect(find.text('No playlists yet.'), findsOneWidget);
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
}
