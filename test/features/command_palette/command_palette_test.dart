import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/command_palette/presentation/command_palette.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/library_navigation_provider.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';

import '../../helpers/pump_studio.dart';
import '../../playback/fake_audio_engine.dart';

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

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (title, artist, album) in [
      ('Jóga', 'Björk', 'Homogenic'),
      ('Hunter', 'Björk', 'Homogenic'),
      ('Teardrop', 'Massive Attack', 'Mezzanine'),
    ]) {
      await db.upsertTrack(
        TracksCompanion.insert(
          locator: '/music/$title.flac',
          title: title,
          artist: Value(artist),
          album: Value(album),
        ),
      );
    }
    final tracks = await db.allTracks();
    await db.createPlaylist('Late Night');
    final playlists = await db.select(db.playlists).get();
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: tracks,
        stubPlaylists: false,
        extraOverrides: [
          playlistsProvider.overrideWith((ref) => Stream.value(playlists)),
        ],
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> openPalette(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
      find.byKey(const ValueKey('command-palette-query')),
      query,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+K opens the palette, Escape closes it', (tester) async {
    await pumpApp(tester);
    await openPalette(tester);
    expect(find.byType(CommandPalette), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    await openPalette(tester);
    expect(find.byType(CommandPalette), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
  });

  testWidgets('Enter opens the top artist in the Library', (tester) async {
    final container = await pumpApp(tester);
    container.read(studioNavProvider.notifier).select(StudioDestination.queue);
    await openPalette(tester);
    await search(tester, 'bjork');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
    expect(container.read(libraryNavigationProvider).artist, 'Björk');
    expect(container.read(studioNavProvider), StudioDestination.library);
  });

  testWidgets('arrow keys pick another result; tracks start playing', (
    tester,
  ) async {
    await pumpApp(tester);
    await openPalette(tester);
    await search(tester, 'homogenic');
    // Album first (title match), then its two tracks (subtitle match).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      engine.lastUri?.toFilePath(),
      anyOf('/music/Jóga.flac', '/music/Hunter.flac'),
    );
  });

  testWidgets('playlists open in the Library', (tester) async {
    final container = await pumpApp(tester);
    await openPalette(tester);
    await search(tester, 'late night');
    await tester.tap(find.text('Late Night'));
    await tester.pumpAndSettle();
    expect(container.read(libraryNavigationProvider).playlistId, isNotNull);
    expect(container.read(studioNavProvider), StudioDestination.library);
  });

  testWidgets('shows when nothing matches', (tester) async {
    await pumpApp(tester);
    await openPalette(tester);
    await search(tester, 'zzzzqqq');
    expect(find.text('No matches'), findsOneWidget);
  });
}
