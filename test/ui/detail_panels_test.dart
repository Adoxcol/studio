import 'package:docking/docking.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/features/track_details/presentation/detail_panels.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';

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
    engine.dispose();
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/one.flac',
        title: 'First song',
        artist: const Value('Aria'),
        album: const Value('Blue album'),
        trackNumber: const Value(1),
        durationMs: const Value(180000),
      ),
    );
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: '/music/two.flac',
        title: 'Second song',
        artist: const Value('Hal'),
        album: const Value('Red album'),
        trackNumber: const Value(1),
        durationMs: const Value(240000),
      ),
    );
    await tester.pumpWidget(
      testStudioApp(db: db, engine: engine, tracks: await db.allTracks()),
    );
    await tester.pump();
  }

  Future<void> inspectSecond(WidgetTester tester) async {
    await tester.tap(
      find.text('Second song').first,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
  }

  testWidgets('three independent dock tabs have useful empty states', (
    tester,
  ) async {
    await pumpApp(tester);
    final layout = tester.widget<Docking>(find.byType(Docking)).layout!;
    for (final label in ['Artist', 'Album', 'Track']) {
      expect(layout.findDockingItem(label.toLowerCase()), isNotNull);
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Play a song or right-click a library track and choose View details.',
        ),
        findsOneWidget,
      );
    }
    await tester.tap(find.byTooltip('Now Playing'));
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingPage), findsOneWidget);
  });

  testWidgets(
    'inspection opens Track and synchronizes Album and Artist without playing',
    (tester) async {
      await pumpApp(tester);
      await inspectSecond(tester);
      expect(find.byType(TrackDetailPanel), findsOneWidget);
      expect(engine.playCount, 0);
      final trackPanel = find.byType(TrackDetailPanel);
      expect(
        find.descendant(of: trackPanel, matching: find.text('Second song')),
        findsOneWidget,
      );

      await tester.tap(find.text('Album').first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlbumDetailPanel),
          matching: find.text('Red album'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Artist').first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ArtistDetailPanel),
          matching: find.text('Hal'),
        ),
        findsWidgets,
      );

      // Inspecting the same track again must reveal Track, not leave Artist active.
      await inspectSecond(tester);
      expect(find.byType(TrackDetailPanel), findsOneWidget);
    },
  );

  testWidgets(
    'follow playback switches inspected metadata back to current and follows next',
    (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('First song').first);
      await tester.pumpAndSettle();
      await inspectSecond(tester);
      await tester.tap(find.text('Follow playback'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TrackDetailPanel),
          matching: find.text('First song'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Next'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(TrackDetailPanel),
          matching: find.text('Second song'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('detail tab can be detached into a separate dock pane', (
    tester,
  ) async {
    await pumpApp(tester);
    await inspectSecond(tester);
    final layout = tester.widget<Docking>(find.byType(Docking)).layout!;
    layout.moveItem(
      draggedItem: layout.findDockingItem('artist')!,
      targetArea: layout.findDockingItem('queue')!,
      dropPosition: DropPosition.left,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArtistDetailPanel), findsOneWidget);
    expect(find.byType(TrackDetailPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long metadata remains scrollable in a narrow short detail pane',
    (tester) async {
      final track = testTrack(
        title: List.filled(8, 'Long title').join(' '),
        locator:
            'C:/Music/${List.filled(15, 'long-folder').join('/')}/song.flac',
      );
      await tester.pumpWidget(
        testStudioApp(
          db: db,
          engine: engine,
          tracks: [track],
          child: MaterialApp(
            theme: StudioTheme.light(),
            home: const Scaffold(
              body: SizedBox(
                width: 280,
                height: 300,
                child: TrackDetailPanel(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TrackDetailPanel)),
      );
      container.read(detailSelectionProvider.notifier).inspect(track.id);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('File / location'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('File / location'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(container.read(playbackControllerProvider).trackId, isNull);
    },
  );
}
