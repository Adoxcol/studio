import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/artist_artwork/data/fanart_settings_store.dart';
import 'package:studio/features/artist_artwork/presentation/fanart_settings.dart';
import 'package:studio/theming/studio_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('masked keys save, validate and remove in a narrow panel', (
    tester,
  ) async {
    final store = FanartSettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [fanartSettingsStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 280, child: FanartSettingsPanel()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final project = find.byKey(const ValueKey('fanart-project-key'));
    final personal = find.byKey(const ValueKey('fanart-personal-key'));
    expect(tester.widget<TextField>(project).obscureText, isTrue);
    expect(tester.widget<TextField>(personal).obscureText, isTrue);
    await tester.enterText(project, 'a' * 32);
    await tester.enterText(personal, 'b' * 32);
    await tester.tap(find.text('Save keys'));
    await tester.pumpAndSettle();
    expect(store.load().headers, {'api-key': 'a' * 32, 'client-key': 'b' * 32});
    expect(find.textContaining('Saved locally.'), findsOneWidget);
    await tester.enterText(project, 'bad key');
    await tester.tap(find.text('Save keys'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Keys must contain'), findsOneWidget);
    expect(store.load().projectKey, 'a' * 32);
    await tester.tap(find.text('Remove keys'));
    await tester.pumpAndSettle();
    expect(store.load().enabled, isFalse);
    expect(tester.widget<TextField>(project).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
