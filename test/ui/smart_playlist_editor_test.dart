import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/features/smart_playlists/presentation/smart_playlist_editor.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_theme.dart';
import '../helpers/pump_studio.dart';
import '../helpers/tracks.dart';
import '../playback/fake_audio_engine.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'narrow editor previews all/any, reacts to library updates and saves',
    (tester) async {
      tester.view.physicalSize = const Size(440, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final updates = StreamController<List<Track>>.broadcast();
      addTearDown(updates.close);
      final initial = SmartPlaylistDefinition(
        rules: const [
          SmartRule(SmartField.genre, SmartOperator.equals, 'Ambient'),
          SmartRule(SmartField.year, SmartOperator.atLeast, '2020'),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioDatabaseProvider.overrideWithValue(db),
            libraryTracksProvider.overrideWith((ref) => updates.stream),
          ],
          child: MaterialApp(
            theme: StudioTheme.light(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showSmartPlaylistEditor(
                    context: context,
                    initial: initial,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final tracks = [
        testTrack(id: 1, genre: 'Ambient', year: 2024),
        testTrack(id: 2, genre: 'Jazz', year: 2024),
      ];
      updates.add(tracks);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('smart-preview-count')),
      );
      expect(find.text('1 matching track'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButton<bool>).first);
      await tester.tap(find.byType(DropdownButton<bool>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('any rule').last);
      await tester.pumpAndSettle();
      expect(find.text('2 matching tracks'), findsOneWidget);
      updates.add([...tracks, testTrack(id: 3, genre: 'Ambient', year: 1990)]);
      await tester.pumpAndSettle();
      expect(find.text('3 matching tracks'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('smart-playlist-name')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('smart-playlist-name')),
        'Late night',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-smart-playlist')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      final playlist = (await db.allPlaylists()).single;
      expect(playlist.name, 'Late night');
      expect(
        SmartPlaylistDefinition.decode(playlist.smartRules!).matchAll,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saving current search opens a smart playlist and restores search on Back',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = StudioDatabase.memory();
      addTearDown(db.close);
      final engine = FakeAudioEngine();
      addTearDown(engine.dispose);
      final tracks = [
        testTrack(id: 1, title: 'Night music'),
        testTrack(id: 2, title: 'Day music'),
      ];
      await db.upsertFolder('/music');
      for (final track in tracks) {
        await db.upsertTrack(track.toCompanion(true));
      }
      await tester.pumpWidget(
        testStudioApp(
          db: db,
          engine: engine,
          tracks: tracks,
          stubPlaylists: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search your library'),
        'Night',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Save as smart playlist'));
      await tester.pumpAndSettle();
      expect(find.text('1 matching track'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('smart-playlist-name')),
        'Night rules',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-smart-playlist')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit rules'), findsOneWidget);
      final saved = (await db.allPlaylists()).single;
      final definition = SmartPlaylistDefinition.decode(saved.smartRules!);
      expect(definition.rules.single.field, SmartField.search);
      expect(definition.rules.single.value, 'Night');
      expect(definition.sort, LibrarySort.title);
      await tester.tap(find.text('Edit rules'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove rule'));
      await tester.pump();
      expect(find.text('Add at least one rule.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('save-smart-playlist')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await db.allPlaylists()).single.smartRules, saved.smartRules);
      await tester.tap(find.text('Edit rules'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('smart-playlist-name')),
        'Renamed nights',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-smart-playlist')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 350)),
      );
      await tester.pumpAndSettle();
      expect((await db.allPlaylists()).single.id, saved.id);
      expect((await db.allPlaylists()).single.name, 'Renamed nights');
      await tester.tap(find.byTooltip('Back to All'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Night'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
