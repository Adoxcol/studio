import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/library_folders/presentation/library_folder_actions.dart';
import 'package:studio/features/library_folders/presentation/library_folders_panel.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/scan_progress.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_theme.dart';

class _Scan extends LibraryScanNotifier {
  final folders = <LibraryFolder>[];
  final changes = StreamController<List<LibraryFolder>>.broadcast();
  bool fail = false;
  int calls = 0;
  @override
  ScanProgress build() => ScanProgress.idle;
  @override
  Future<void> scanFolder(String path) async {
    calls++;
    if (fail) throw StateError('unavailable');
    folders.add(LibraryFolder(id: calls, path: path));
    changes.add(List.of(folders));
  }

  @override
  Future<void> removeFolder(int folderId) async {
    folders.removeWhere((folder) => folder.id == folderId);
    changes.add(List.of(folders));
  }

  void setBusy(bool active) => state = ScanProgress(active: active);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Scan scan;
  setUp(() => scan = _Scan());
  tearDown(() async => scan.changes.close());

  Widget app(
    MusicFolderPicker picker, {
    bool twoPanels = false,
    String query = '',
  }) => ProviderScope(
    overrides: [
      libraryScanProvider.overrideWith(() => scan),
      libraryFoldersProvider.overrideWith((ref) => scan.changes.stream),
      musicFolderPickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      theme: StudioTheme.light(),
      home: Scaffold(
        body: Row(
          children: [
            SizedBox(width: 280, child: LibraryFoldersPanel(query: query)),
            if (twoPanels)
              const Expanded(
                child: SingleChildScrollView(
                  child: LibraryFoldersPanel(embedded: true),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  testWidgets(
    'adding and removing folders stays synchronized across both layouts',
    (tester) async {
      await tester.pumpWidget(
        app(() async => '/music/Records', twoPanels: true),
      );
      scan.changes.add([]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add folder').first);
      await tester.pumpAndSettle();
      expect(find.text('Records'), findsNWidgets(2));
      expect(find.text('/music/Records'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Remove folder').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('will not be deleted'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Records'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Remove folder').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Records'), findsNothing);
      expect(find.textContaining('No music folders yet.'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker is shared, cancel changes nothing, scan errors remain retryable',
    (tester) async {
      var calls = 0;
      final pending = Completer<String?>();
      await tester.pumpWidget(
        app(() {
          calls++;
          return calls == 1 ? pending.future : Future.value('/music/Records');
        }, twoPanels: true),
      );
      await tester.tap(find.text('Add folder').first);
      await tester.pump();
      for (final button in tester.widgetList<TextButton>(
        find.byWidgetPredicate((widget) => widget is TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      expect(calls, 1);
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(scan.calls, 0);

      scan.fail = true;
      await tester.tap(find.text('Add folder').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not add this folder'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('add-music-folder')).first,
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('active scans disable mutations and long paths fit a narrow pane', (
    tester,
  ) async {
    await tester.pumpWidget(app(() async => null));
    scan.changes.add([
      const LibraryFolder(
        id: 1,
        path:
            '/music/A very long music folder name/Another really long folder name',
      ),
    ]);
    scan.setBusy(true);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('add-music-folder')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Remove folder'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
