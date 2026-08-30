import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/now_playing/up_next_panel.dart';

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

  testWidgets('follows the canonical queue and excludes the current track', (
    tester,
  ) async {
    for (final title in ['First', 'Second', 'Third']) {
      await db.upsertTrack(
        TracksCompanion.insert(locator: '/music/$title.flac', title: title),
      );
    }
    final tracks = await db.allTracks();

    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: tracks,
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(body: UpNextPanel()),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(UpNextPanel)),
    );

    await container
        .read(playbackControllerProvider.notifier)
        .playTracks(tracks.map((track) => track.id).toList());
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Third'), findsOneWidget);

    await container.read(playbackControllerProvider.notifier).skipNext();
    await tester.pump();

    expect(find.text('Second'), findsNothing);
    expect(find.text('Third'), findsOneWidget);

    await tester.tap(find.text('Third'));
    await tester.pump();

    expect(engine.lastUri.toString(), contains('Third.flac'));
    expect(find.text('Nothing up next.'), findsOneWidget);
  });
}
