import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/queue/queue_page.dart';

import '../helpers/pump_studio.dart';
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

  testWidgets('selection removes multiple upcoming tracks and supports undo', (
    tester,
  ) async {
    for (final title in const ['Current', 'Second', 'Third']) {
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/music/$title.flac',
          title: title,
          artist: const Value('Queue Artist'),
        ),
      );
    }
    final tracks = await db.allTracks();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: tracks,
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(body: QueuePage()),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QueuePage)),
    );
    await container
        .read(playbackControllerProvider.notifier)
        .playTracks(tracks.map((track) => track.id).toList());
    await tester.pump();

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Remove selected'));
    await tester.pump();

    expect(container.read(playbackControllerProvider).queueIds, [tracks[0].id]);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Removed 2 tracks'), findsOneWidget);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump();
    expect(
      container.read(playbackControllerProvider).queueIds,
      tracks.map((track) => track.id).toList(),
    );
  });
}
