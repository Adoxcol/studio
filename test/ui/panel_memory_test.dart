import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/layout/workspace_widget.dart';
import 'package:studio/ui/library_browser/library_browse_view.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

class _Counter extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

final _counter = NotifierProvider<_Counter, int>(_Counter.new);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('large album sections only mount nearby rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.light(),
        home: Scaffold(
          body: LibraryBrowseView(
            tab: LibraryTab.albums,
            artists: const [],
            genres: const [],
            albums: [
              AlbumSection(
                artist: 'Artist',
                albums: [
                  for (var i = 0; i < 2000; i++)
                    LibraryGroup(name: 'Album $i', trackCount: 1),
                ],
              ),
            ],
            onSelectArtist: (_) {},
            onSelectAlbum: (_, _) {},
            onSelectGenre: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(CoverArt).evaluate().length, lessThan(30));
    expect(find.text('Album 1999'), findsNothing);
    await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byType(CoverArt).evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unopened panels stay lazy and hidden subscriptions pause', (
    tester,
  ) async {
    var builds = 0;
    final active = ValueNotifier(false);
    addTearDown(active.dispose);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (context, enabled, child) => TickerMode(
                enabled: enabled,
                child: DeferredWorkspacePanel(
                  builder: (_) => Consumer(
                    builder: (context, ref, child) {
                      builds++;
                      final value = ref.watch(_counter);
                      return Column(
                        children: [Text('$value'), const TextField()],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(builds, 0);
    active.value = true;
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'keep my state');
    final field = tester.state(find.byType(TextField));
    active.value = false;
    await tester.pumpAndSettle();
    final hiddenBuilds = builds;
    container.read(_counter.notifier).increment();
    await tester.pumpAndSettle();
    expect(builds, hiddenBuilds);
    active.value = true;
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('keep my state'), findsOneWidget);
    expect(tester.state(find.byType(TextField)), same(field));
  });
}
