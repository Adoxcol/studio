import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:studio/features/subsonic/data/subsonic_offline_store.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_panel.dart';
import 'package:studio/features/subsonic/presentation/subsonic_offline_providers.dart';
import 'package:studio/features/subsonic/presentation/subsonic_providers.dart';
import 'package:studio/theming/studio_theme.dart';

const _config = SubsonicServerConfig(
  serverUrl: 'https://music.example.com',
  username: 'rob',
  password: 'pw',
);

void main() {
  testWidgets('summarises downloads and removes them after confirming', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('studio-offline-panel');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final server = SubsonicOfflineStore.serverKey(_config);
    final dir = Directory(p.join(root.path, server))..createSync();
    File(p.join(dir.path, 'a.flac')).writeAsBytesSync(List.filled(3072, 1));
    File(
      p.join(dir.path, 'index.json'),
    ).writeAsStringSync('{"a":{"file":"a.flac","bytes":3072}}');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subsonicSettingsStoreProvider.overrideWithValue(
            MemorySubsonicSettingsStore(_config),
          ),
          subsonicOfflineStoreProvider.overrideWithValue(
            SubsonicOfflineStore(root),
          ),
          subsonicDownloadHttpClientProvider.overrideWithValue(
            MockClient((_) async => http.Response('', 500)),
          ),
        ],
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(body: SubsonicOfflinePanel()),
        ),
      ),
    );

    expect(find.text('1 track available offline · 3 KB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('offline-remove-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('offline-remove-all-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No tracks downloaded'), findsOneWidget);
    expect(root.existsSync(), isFalse);
  });

  testWidgets('hides itself when no server is configured', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SubsonicOfflinePanel())),
      ),
    );
    expect(find.byKey(const ValueKey('offline-summary')), findsNothing);
  });
}
