import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/app.dart';
import 'package:studio/theming/studio_palette.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Studio shell shows library placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));

    expect(find.text('Library'), findsOneWidget);
    expect(
      find.text('Library is empty. Local files will show up here.'),
      findsOneWidget,
    );
    expect(find.text('Not playing'), findsOneWidget);
    expect(find.byTooltip('Library'), findsOneWidget);
    expect(find.byTooltip('Now Playing'), findsOneWidget);
    expect(find.byTooltip('Queue'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('icon rail opens Settings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();

    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('light theme uses Editorial Mono background', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).scaffoldBackgroundColor, StudioPalette.light().bg);
  });
}
