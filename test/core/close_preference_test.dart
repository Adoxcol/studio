import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/core/desktop/close_preference_store.dart';
import 'package:studio/core/desktop/close_window_dialog.dart';
import 'package:studio/theming/studio_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('asks until the user remembers a choice', () {
    expect(
      decideClose(
        trayReady: true,
        quitting: false,
        preference: ClosePreference.defaults,
      ),
      CloseDecision.ask,
    );
    expect(
      decideClose(
        trayReady: true,
        quitting: false,
        preference: const ClosePreference(
          ask: false,
          remember: CloseAction.quit,
        ),
      ),
      CloseDecision.quit,
    );
    expect(
      decideClose(
        trayReady: true,
        quitting: false,
        preference: const ClosePreference(
          ask: false,
          remember: CloseAction.background,
        ),
      ),
      CloseDecision.background,
    );
  });

  test('quits when the tray is missing or already quitting', () {
    expect(
      decideClose(
        trayReady: false,
        quitting: false,
        preference: ClosePreference.defaults,
      ),
      CloseDecision.quit,
    );
    expect(
      decideClose(
        trayReady: true,
        quitting: true,
        preference: const ClosePreference(
          ask: false,
          remember: CloseAction.background,
        ),
      ),
      CloseDecision.quit,
    );
  });

  test('file store round-trips a remembered quit', () {
    final file = File(
      '${Directory.systemTemp.path}/studio-close-pref-test.json',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final store = FileClosePreferenceStore(file);
    store.save(const ClosePreference(ask: false, remember: CloseAction.quit));
    final loaded = store.load();
    expect(loaded.ask, isFalse);
    expect(loaded.remember, CloseAction.quit);
  });

  testWidgets('close dialog returns quit when Close is tapped', (tester) async {
    CloseWindowChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.light(),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                choice = await showDialog<CloseWindowChoice>(
                  context: context,
                  builder: (_) => const CloseWindowDialog(),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Close Studio?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('close-remember')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('close-quit')));
    await tester.pumpAndSettle();
    expect(choice?.action, CloseAction.quit);
    expect(choice?.remember, isTrue);
  });

  testWidgets('run in background does not remember unless ticked', (
    tester,
  ) async {
    CloseWindowChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.light(),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                choice = await showDialog<CloseWindowChoice>(
                  context: context,
                  builder: (_) => const CloseWindowDialog(),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('close-background')));
    await tester.pumpAndSettle();
    expect(choice?.action, CloseAction.background);
    expect(choice?.remember, isFalse);
  });
}
