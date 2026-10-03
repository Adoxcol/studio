import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studio/features/scrobbling/data/scrobble_settings_store.dart';
import 'package:studio/features/scrobbling/domain/scrobble_settings.dart';
import 'package:studio/features/scrobbling/presentation/scrobble_providers.dart';
import 'package:studio/features/scrobbling/presentation/scrobbling_settings_panel.dart';
import 'package:studio/theming/studio_theme.dart';

void main() {
  Future<MemoryScrobbleSettingsStore> pump(
    WidgetTester tester, {
    required http.Client client,
    ScrobbleSettings initial = ScrobbleSettings.defaults,
  }) async {
    final store = MemoryScrobbleSettingsStore(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scrobbleSettingsStoreProvider.overrideWithValue(store),
          scrobbleHttpClientProvider.overrideWithValue(client),
        ],
        child: MaterialApp(
          theme: StudioTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: ScrobblingSettingsPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(); // Wait for AsyncNotifier to resolve
    return store;
  }

  testWidgets('connects and disconnects ListenBrainz', (tester) async {
    final store = await pump(
      tester,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Token good-token');
        return http.Response('{"valid":true,"user_name":"rob"}', 200);
      }),
    );
    await tester.enterText(
      find.byKey(const ValueKey('listenbrainz-token')),
      ' good-token ',
    );
    await tester.tap(find.byKey(const ValueKey('listenbrainz-connect')));
    await tester.pumpAndSettle();
    expect(find.text('Connected as rob.'), findsOneWidget);
    expect(store.value.listenBrainzToken, 'good-token');

    await tester.tap(find.byKey(const ValueKey('listenbrainz-disconnect')));
    await tester.pumpAndSettle();
    expect(store.value.listenBrainzConnected, isFalse);
    expect(find.byKey(const ValueKey('listenbrainz-token')), findsOneWidget);
  });

  testWidgets('shows why a ListenBrainz token was refused', (tester) async {
    await pump(
      tester,
      client: MockClient((_) async => http.Response('{"valid":false}', 200)),
    );
    await tester.enterText(
      find.byKey(const ValueKey('listenbrainz-token')),
      'bad',
    );
    await tester.tap(find.byKey(const ValueKey('listenbrainz-connect')));
    await tester.pumpAndSettle();
    expect(
      find.text('ListenBrainz did not accept this token.'),
      findsOneWidget,
    );
  });

  testWidgets('asks for Last.fm keys before connecting', (tester) async {
    final store = await pump(
      tester,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(find.byKey(const ValueKey('lastfm-connect')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('lastfm-api-key')), 'k');
    await tester.enterText(find.byKey(const ValueKey('lastfm-secret')), 's');
    await tester.tap(find.byKey(const ValueKey('lastfm-save-keys')));
    await tester.pumpAndSettle();
    expect(store.value.hasLastFmKeys, isTrue);
    expect(find.byKey(const ValueKey('lastfm-connect')), findsOneWidget);
  });

  testWidgets('an expired Last.fm session asks to reconnect', (tester) async {
    await pump(
      tester,
      client: MockClient((_) async => http.Response('{}', 200)),
      initial: const ScrobbleSettings(
        lastFmApiKey: 'k',
        lastFmSecret: 's',
        lastFmExpired: true,
      ),
    );
    expect(
      find.textContaining('stopped accepting the saved session'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lastfm-connect')), findsOneWidget);
  });
}
