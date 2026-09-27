import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/listening_stats/presentation/listening_stats_providers.dart';
import 'package:studio/features/listening_stats/presentation/stats_page.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_theme.dart';

void main() {
  late StudioDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => db = StudioDatabase.memory());
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studioDatabaseProvider.overrideWithValue(db),
          statsClockProvider.overrideWithValue(() => DateTime(2026, 9, 27, 12)),
          playCountProvider.overrideWith((ref) => Stream.value(0)),
        ],
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(body: StatsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('formatListening', () {
    expect(formatListening(const Duration(minutes: 45)), '45 m');
    expect(formatListening(const Duration(hours: 3, minutes: 25)), '3 h 25 m');
  });

  testWidgets('shows an empty state before anything is played', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('stats-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-empty')), findsOneWidget);
  });

  testWidgets('summarises plays for the period and the year', (tester) async {
    final semantics = tester.ensureSemantics();
    for (final (day, title) in [(20, 'Jóga'), (25, 'Jóga'), (26, 'Hunter')]) {
      await db.recordPlay(
        title: title,
        artist: 'Björk',
        album: 'Homogenic',
        durationMs: 300000,
        playedAt: DateTime(2026, 9, day, 20).toUtc(),
      );
    }
    await db.recordPlay(
      title: 'Old',
      artist: 'Someone',
      durationMs: 60000,
      playedAt: DateTime(2026, 2, 1).toUtc(),
    );
    await pump(tester);

    // Last 30 days: the three September plays.
    expect(find.bySemanticsLabel('Plays: 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Listening time: 15 m'), findsOneWidget);
    expect(find.text('Jóga'), findsWidgets);
    expect(find.text('2 plays'), findsWidgets);

    await tester.tap(find.text('This year'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Plays: 4'), findsOneWidget);

    expect(find.text('2026 in review'), findsOneWidget);
    expect(find.bySemanticsLabel('Top artist: Björk, 3 plays'), findsOneWidget);
    expect(find.bySemanticsLabel('September: 3 plays'), findsOneWidget);
    expect(find.bySemanticsLabel('February: 1 play'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing recorded in 2025.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('clearing history asks first', (tester) async {
    await db.recordPlay(
      title: 'Keep?',
      playedAt: DateTime(2026, 9, 26).toUtc(),
    );
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('stats-clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await db.playEventsBetween(), hasLength(1));

    await tester.tap(find.byKey(const ValueKey('stats-clear-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stats-clear-confirm')));
    await tester.pumpAndSettle();
    expect(await db.playEventsBetween(), isEmpty);
  });
}
