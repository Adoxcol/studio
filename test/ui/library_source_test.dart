import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/library_source/data/library_source_store.dart';
import 'package:studio/features/library_source/presentation/library_source_provider.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/library/database.dart';
import 'package:studio/providers/playable_resolver.dart';

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

  final local = testTrack(
    id: 1,
    title: 'Local Song',
    artist: 'Local Artist',
    genre: 'Folk',
  );
  final remote = testTrack(
    id: 2,
    title: 'Server Song',
    artist: 'Server Artist',
    genre: 'Techno',
    locator: 'nd-2',
    folderId: null,
    source: TrackLocator.subsonic,
  );

  Future<void> pump(WidgetTester tester, LibrarySourceStore store) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: [local],
        folders: const [LibraryFolder(id: 1, path: '/music')],
        extraOverrides: [
          librarySourceStoreProvider.overrideWithValue(store),
          subsonicTracksProvider.overrideWith((ref) => Stream.value([remote])),
          subsonicSettingsStoreProvider.overrideWithValue(
            MemorySubsonicSettingsStore(
              const SubsonicServerConfig(
                serverUrl: 'https://music.example.com',
                username: 'rob',
                password: 'pw',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  testWidgets('the Navidrome source holds across Library tabs', (tester) async {
    final store = MemoryLibrarySourceStore();
    await pump(tester, store);
    expect(find.text('Local Song'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-source-navidrome')));
    await tester.pumpAndSettle();
    expect(find.text('Server Song'), findsOneWidget);
    expect(find.text('Local Song'), findsNothing);
    // Folders are this computer's; Navidrome has none to browse here.
    expect(find.text('Folders'), findsNothing);
    expect(store.source, LibrarySource.navidrome);

    await tapText(tester, 'Artists');
    expect(find.text('Server Artist'), findsOneWidget);
    expect(find.text('Local Artist'), findsNothing);

    await tapText(tester, 'Genres');
    expect(find.text('Techno'), findsOneWidget);
    expect(find.text('Folk'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('library-source-local')));
    await tester.pumpAndSettle();
    expect(find.text('Folk'), findsOneWidget);
    expect(find.text('Techno'), findsNothing);
    expect(store.source, LibrarySource.local);
  });

  testWidgets('the saved source is used on the next launch', (tester) async {
    await pump(tester, MemoryLibrarySourceStore(LibrarySource.navidrome));
    expect(find.text('Server Song'), findsOneWidget);
    expect(find.text('Local Song'), findsNothing);
  });

  test('without a server the source is always this computer', () {
    expect(
      effectiveLibrarySource(
        chosen: LibrarySource.navidrome,
        hasLocalFolders: true,
        hasNavidrome: false,
      ),
      LibrarySource.local,
    );
    expect(
      effectiveLibrarySource(
        chosen: null,
        hasLocalFolders: false,
        hasNavidrome: true,
      ),
      LibrarySource.navidrome,
    );
  });
}
