import 'package:docking/docking.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/library/database.dart';
import 'package:studio/theming/studio_theme.dart';
import 'package:studio/ui/layout/studio_dock_theme.dart';
import 'package:studio/ui/layout/workspace_widget.dart';

import '../helpers/pump_studio.dart';
import '../playback/fake_audio_engine.dart';

Finder tab(String id) => find.byWidgetPredicate(
  (widget) =>
      widget is Draggable<DraggableData> &&
      (widget.data?.tabData.value as DockingItem?)?.id == id,
  description: 'dock tab $id',
);

DockingLayout layoutOf(WidgetTester tester) =>
    tester.widget<Docking>(find.byType(Docking)).layout!;

List<String> tabOrder(DockingTabs tabs) => [
  for (var i = 0; i < tabs.childrenCount; i++) tabs.childAt(i).id as String,
];

Future<TestGesture> dragTab(
  WidgetTester tester,
  String id,
  Offset target,
) async {
  final gesture = await tester.startGesture(
    tester.getCenter(tab(id)),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('workspace menu', () {
    late StudioDatabase db;
    late FakeAudioEngine engine;
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
      await tester.pumpWidget(testStudioApp(db: db, engine: engine));
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(
      WidgetTester tester,
      String id, {
      bool blank = false,
    }) async {
      final layout = layoutOf(tester);
      final area =
          layout.findDockingTabsWithItem(id) ?? layout.findDockingItem(id)!;
      final position = blank
          ? tester.getTopRight(find.byKey(ObjectKey(area))) +
                const Offset(-55, 16)
          : tester.getCenter(tab(id));
      await tester.tapAt(position, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(find.text('Add widget to this pane'), findsOneWidget);
    }

    testWidgets('left rail exposes every workspace widget', (tester) async {
      await pumpApp(tester);

      for (final label in [
        'Library',
        'Now Playing',
        'Playback Mode',
        'Queue',
        'Artist',
        'Album',
        'Track',
        'Settings',
      ]) {
        expect(find.byTooltip(label), findsOneWidget);
      }
    });

    testWidgets(
      'right-click labels and empty strip space; content stays untouched',
      (tester) async {
        await pumpApp(tester);
        await openMenu(tester, 'nowPlaying', blank: true);
        for (final widget in WorkspaceWidget.values) {
          expect(
            find.byKey(ValueKey('workspace-add-${widget.name}')),
            findsOneWidget,
          );
        }
        await tester.tapAt(const Offset(700, 500));
        await tester.pumpAndSettle();
        await openMenu(tester, 'artist');
        await tester.tapAt(const Offset(700, 500));
        await tester.pumpAndSettle();
        await tester.tapAt(
          const Offset(700, 500),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('Add widget to this pane'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('move existing widget here without duplicates or playback', (
      tester,
    ) async {
      await pumpApp(tester);
      final layout = layoutOf(tester);
      final artist = layout.findDockingItem('artist');
      await openMenu(tester, 'library', blank: true);
      await tester.tap(find.byKey(const ValueKey('workspace-add-artist')));
      await tester.pumpAndSettle();
      expect(layout.findDockingItem('artist'), same(artist));
      expect(tabOrder(layout.findDockingTabsWithItem('library')!), [
        'library',
        'artist',
      ]);
      expect(layout.layoutAreas().whereType<DockingItem>().length, 6);
      expect(engine.playCount, 0);
      await openMenu(tester, 'artist');
      await tester.tap(find.byKey(const ValueKey('workspace-add-artist')));
      await tester.pumpAndSettle();
      expect(layout.layoutAreas().whereType<DockingItem>().length, 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'hide/reopen through menu and navigation; Library remains recoverable',
      (tester) async {
        await pumpApp(tester);
        final layout = layoutOf(tester);
        await tester.tap(tab('artist'));
        await tester.pumpAndSettle();
        await openMenu(tester, 'artist');
        await tester.tap(find.text('Hide Artist'));
        await tester.pumpAndSettle();
        expect(layout.findDockingItem('artist'), isNull);
        await openMenu(tester, 'library');
        await tester.tap(find.byKey(const ValueKey('workspace-add-artist')));
        await tester.pumpAndSettle();
        expect(
          layout.findDockingTabsWithItem('library'),
          same(layout.findDockingTabsWithItem('artist')),
        );

        await openMenu(tester, 'queue');
        await tester.tap(find.text('Hide Queue'));
        await tester.pumpAndSettle();
        expect(layout.findDockingItem('queue'), isNull);
        await tester.tap(find.byTooltip('Queue'));
        await tester.pumpAndSettle();
        expect(layout.findDockingItem('queue'), isNotNull);

        await tester.tap(tab('library'));
        await tester.pumpAndSettle();
        await openMenu(tester, 'library');
        expect(
          tester
              .widget<PopupMenuItem<String>>(
                find.widgetWithText(PopupMenuItem<String>, 'Hide Library'),
              )
              .enabled,
          isFalse,
        );
        await tester.tap(find.text('Reset layout'));
        await tester.pumpAndSettle();
        expect(layout.findDockingTabsWithItem('library'), isNull);
        expect(tabOrder(layout.findDockingTabsWithItem('artist')!), [
          'nowPlaying',
          'artist',
          'album',
          'track',
        ]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('menu works while maximized and in narrow panes', (
      tester,
    ) async {
      await pumpApp(tester);
      final layout = layoutOf(tester);
      layout.maximizeDockingItem(layout.findDockingItem('library')!);
      await tester.pumpAndSettle();
      await openMenu(tester, 'library', blank: true);
      await tester.tap(find.byKey(const ValueKey('workspace-add-track')));
      await tester.pumpAndSettle();
      expect(layout.maximizedArea, isNull);
      expect(
        layout.findDockingTabsWithItem('library'),
        same(layout.findDockingTabsWithItem('track')),
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(900, 650);
      await tester.pumpAndSettle();
      await openMenu(tester, 'library', blank: true);
      await tester.tap(find.byKey(const ValueKey('workspace-add-album')));
      await tester.pumpAndSettle();
      expect(
        layout.findDockingTabsWithItem('album'),
        same(layout.findDockingTabsWithItem('library')),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('dock motion', () {
    testWidgets('real cross-pane drag preserves content and can split again', (
      tester,
    ) async {
      final layout = DockingLayout(
        root: DockingRow([
          DockingTabs([
            DockingItem(
              id: 'a',
              name: 'Tab a',
              keepAlive: true,
              widget: const TextField(key: ValueKey('saved-input')),
            ),
            DockingItem(
              id: 'b',
              name: 'Tab b',
              keepAlive: true,
              widget: const Text('Pane b'),
            ),
          ]),
          DockingItem(
            id: 'q',
            name: 'Pane q',
            keepAlive: true,
            widget: const Text('Pane q body'),
          ),
        ]),
      );
      addTearDown(layout.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.light(),
          home: Scaffold(
            body: StudioDockChrome(child: Docking(layout: layout)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('saved-input')),
        'unchanged',
      );
      final inputState = tester.state(
        find.byKey(const ValueKey('saved-input')),
      );
      final drag = await dragTab(tester, 'a', tester.getCenter(tab('q')));
      await drag.up();
      await tester.pumpAndSettle();
      expect(tabOrder(layout.findDockingTabsWithItem('q')!), ['a', 'q']);
      await tester.tap(tab('a'));
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byKey(const ValueKey('saved-input'))),
        same(inputState),
      );
      expect(find.text('unchanged'), findsOneWidget);
      // Drop onto the left edge of the other pane to form a new split.
      final split = await dragTab(tester, 'a', const Offset(20, 250));
      await split.up();
      await tester.pumpAndSettle();
      expect(layout.findDockingTabsWithItem('a'), isNull);
      expect(
        tester.state(find.byKey(const ValueKey('saved-input'))),
        same(inputState),
      );
      expect(layout.layoutAreas().whereType<DockingItem>().length, 3);
      expect(tester.takeException(), isNull);
    });

    Future<DockingLayout> pumpDock(
      WidgetTester tester, {
      bool reducedMotion = false,
    }) async {
      final layout = DockingLayout(
        root: DockingTabs([
          for (final id in ['a', 'b', 'c', 'd'])
            DockingItem(
              id: id,
              name: 'Tab $id',
              keepAlive: true,
              closable: false,
              widget: TextField(key: ValueKey('content-$id')),
            ),
        ]),
      );
      addTearDown(layout.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Scaffold(
              body: StudioDockChrome(child: Docking(layout: layout)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return layout;
    }

    testWidgets(
      'real drag reorders left and right and animates intermediate positions',
      (tester) async {
        final layout = await pumpDock(tester);
        await tester.enterText(
          find.byKey(const ValueKey('content-a')),
          'keep my state',
        );
        final state = tester.state(find.byKey(const ValueKey('content-a')));
        final originalRoot = layout.root;
        final start = tester.getTopLeft(tab('b')).dx;
        final drag = await dragTab(tester, 'd', tester.getCenter(tab('b')));
        await drag.up();
        await tester.pump();
        expect(tabOrder(layout.root as DockingTabs), ['a', 'd', 'b', 'c']);
        expect(layout.root, same(originalRoot));
        final firstFrame = tester.getTopLeft(tab('b')).dx;
        await tester.pump(const Duration(milliseconds: 70));
        final middle = tester.getTopLeft(tab('b')).dx;
        await tester.pumpAndSettle();
        final end = tester.getTopLeft(tab('b')).dx;
        expect(firstFrame, closeTo(start, 0.1));
        expect(middle, greaterThan(start));
        expect(middle, lessThan(end));
        expect(
          tester.state(find.byKey(const ValueKey('content-a'))),
          same(state),
        );
        expect(find.text('keep my state'), findsOneWidget);

        final reverse = await dragTab(tester, 'a', const Offset(700, 16));
        await reverse.up();
        await tester.pumpAndSettle();
        expect(tabOrder(layout.root as DockingTabs), ['d', 'b', 'c', 'a']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cancelled drag clears feedback and allows another drag', (
      tester,
    ) async {
      final layout = await pumpDock(tester);
      final drag = await dragTab(tester, 'c', const Offset(400, 250));
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(tabOrder(layout.root as DockingTabs), ['a', 'b', 'c', 'd']);
      expect(find.text('Tab c'), findsOneWidget);
      final next = await dragTab(tester, 'c', tester.getCenter(tab('a')));
      await next.up();
      await tester.pumpAndSettle();
      expect(tabOrder(layout.root as DockingTabs), ['c', 'a', 'b', 'd']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion applies final tab positions immediately', (
      tester,
    ) async {
      final layout = await pumpDock(tester, reducedMotion: true);
      final start = tester.getTopLeft(tab('b')).dx;
      final drag = await dragTab(tester, 'd', tester.getCenter(tab('b')));
      await drag.up();
      await tester.pump();
      final end = tester.getTopLeft(tab('b')).dx;
      expect(end, greaterThan(start));
      await tester.pump(const Duration(milliseconds: 70));
      expect(tester.getTopLeft(tab('b')).dx, end);
      expect(tabOrder(layout.root as DockingTabs), ['a', 'd', 'b', 'c']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('secondary-button motion never starts a tab drag', (
      tester,
    ) async {
      final layout = await pumpDock(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(tab('b')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.moveTo(tester.getCenter(tab('d')));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tabOrder(layout.root as DockingTabs), ['a', 'b', 'c', 'd']);
      expect(find.text('Tab b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
