import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/playlist_management/presentation/playlist_dialogs.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/studio_theme.dart';
import '../helpers/playlists.dart';
import '../helpers/pump_studio.dart';
import '../playback/fake_audio_engine.dart';

Future<void> settleDatabase(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'smart playlists keep rule ordering and explain duplicate behavior',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final rules = SmartPlaylistDefinition(
        rules: const [
          SmartRule(SmartField.format, SmartOperator.equals, 'flac'),
        ],
      ).encode();
      await db.createPlaylist('FLAC collection', smartRules: rules);
      final engine = FakeAudioEngine();
      addTearDown(engine.dispose);
      await tester.pumpWidget(
        testStudioApp(db: db, engine: engine, stubPlaylists: false),
      );
      await settleDatabase(tester);
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FLAC collection'));
      await settleDatabase(tester);
      expect(find.text('Reorder tracks'), findsNothing);
      expect(find.text('Edit rules'), findsOneWidget);
      await tester.tap(find.text('Duplicate playlist'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Copy the rules into a new smart playlist.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Duplicate'));
      await settleDatabase(tester);
      expect((await db.allPlaylists()).map((p) => p.smartRules), [
        rules,
        rules,
      ]);
      expect(find.text('FLAC collection (copy)'), findsOneWidget);
      expect(find.text('Reorder tracks'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reorder editor fits a low-height dark window', (tester) async {
    tester.view.physicalSize = const Size(650, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = StudioDatabase.memory();
    addTearDown(db.close);
    await seedPlaylist(db);
    final playlist = (await db.allPlaylists()).single;
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPlaylistOrderEditor(
                context,
                database: db,
                playlist: playlist,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settleDatabase(tester);
    expect(find.text('Save order').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'name dialog validates blank names and supports keyboard submission',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showPlaylistNameDialog(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Create'))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('playlist-name-field')),
        '  Night drive  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 'Night drive');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow reorder editor drags duplicate occurrences and only persists Save',
    (tester) async {
      tester.view.physicalSize = const Size(440, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final id = await seedPlaylist(db);
      final playlist = (await db.allPlaylists()).single;
      final original = await db.playlistItems(id);
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPlaylistOrderEditor(
                  context,
                  database: db,
                  playlist: playlist,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settleDatabase(tester);
      expect(find.text('A'), findsNWidgets(2));
      await tester.drag(
        find.byType(ReorderableDragStartListener).first,
        const Offset(0, 150),
      );
      await tester.pumpAndSettle();
      final moved = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      expect(moved.itemCount, 4);
      expect(
        tester.getTopLeft(find.text('B')).dy,
        lessThan(tester.getTopLeft(find.text('A').first).dy),
      );
      expect(
        (await db.playlistItems(id)).map((e) => e.entryId),
        original.map((e) => e.entryId),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await db.playlistItems(id)).map((e) => e.entryId),
        original.map((e) => e.entryId),
      );
      await tester.tap(find.text('Open'));
      await settleDatabase(tester);
      await tester.tap(find.byTooltip('Move down').first);
      await tester.pump();
      await tester.tap(find.text('Save order'));
      await settleDatabase(tester);
      expect((await db.playlistItems(id)).map((e) => e.entryId), [
        original[1].entryId,
        original[0].entryId,
        original[2].entryId,
        original[3].entryId,
      ]);
      expect(find.text('Reorder tracks'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'stale reorder displays an error without losing newly added tracks',
    (tester) async {
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final id = await seedPlaylist(db);
      final playlist = (await db.allPlaylists()).single;
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPlaylistOrderEditor(
                  context,
                  database: db,
                  playlist: playlist,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await settleDatabase(tester);
      await tester.tap(find.byTooltip('Move down').first);
      await tester.pump();
      await db.addTrackToPlaylist(
        playlistId: id,
        trackId: (await db.allTracks()).first.id,
      );
      await tester.tap(find.text('Save order'));
      await settleDatabase(tester);
      expect(find.textContaining('Playlist contents changed.'), findsOneWidget);
      expect(await db.playlistItems(id), hasLength(5));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'library actions rename, duplicate and confirm deletion without deleting music',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      await seedPlaylist(db);
      final engine = FakeAudioEngine();
      addTearDown(engine.dispose);
      await tester.pumpWidget(
        testStudioApp(
          db: db,
          engine: engine,
          tracks: await db.allTracks(),
          stubPlaylists: false,
        ),
      );
      await settleDatabase(tester);
      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original'));
      await settleDatabase(tester);
      expect(find.text('Reorder tracks'), findsOneWidget);
      await tester.tap(find.text('Rename playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('playlist-name-field')),
        'Favorites',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Rename'));
      await settleDatabase(tester);
      expect((await db.allPlaylists()).single.name, 'Favorites');
      expect(find.text('Favorites'), findsOneWidget);
      await tester.tap(find.text('Duplicate playlist'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Favorites (copy)'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Duplicate'));
      await settleDatabase(tester);
      expect(await db.allPlaylists(), hasLength(2));
      expect(find.text('Favorites (copy)'), findsOneWidget);
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'music files and library tracks will remain untouched',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await db.allPlaylists(), hasLength(2));
      await tester.tap(find.text('Delete playlist'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await settleDatabase(tester);
      expect((await db.allPlaylists()).single.name, 'Favorites');
      expect(await db.allTracks(), hasLength(3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
