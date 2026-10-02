import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:studio/features/scrobbling/data/lastfm_client.dart';
import 'package:studio/features/scrobbling/data/listenbrainz_client.dart';
import 'package:studio/features/scrobbling/data/scrobble_queue_store.dart';
import 'package:studio/features/scrobbling/data/scrobble_settings_store.dart';
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/domain/scrobble_settings.dart';
import 'package:studio/features/scrobbling/domain/scrobble_tracker.dart';
import 'package:studio/features/scrobbling/domain/scrobbler.dart';
import 'package:studio/state/playback_provider.dart';

final scrobbleSettingsStoreProvider = Provider<ScrobbleSettingsStore>(
  (ref) => MemoryScrobbleSettingsStore(),
);

final scrobbleQueueStoreProvider = Provider<ScrobbleQueueStore>(
  (ref) => MemoryScrobbleQueueStore(),
);

final scrobbleHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

class ScrobbleSettingsNotifier extends AsyncNotifier<ScrobbleSettings> {
  String? _pendingLastFmToken;

  @override
  Future<ScrobbleSettings> build() =>
      ref.watch(scrobbleSettingsStoreProvider).load();

  bool get awaitingLastFmApproval => _pendingLastFmToken != null;

  LastFmClient _lastFm() => LastFmClient(
    apiKey: state.requireValue.effectiveLastFmApiKey,
    secret: state.requireValue.effectiveLastFmSecret,
    httpClient: ref.read(scrobbleHttpClientProvider),
  );

  void _save(ScrobbleSettings next) {
    state = AsyncData(next);
    ref.read(scrobbleSettingsStoreProvider).save(next);
  }

  void setLastFmKeys(String apiKey, String secret) {
    _pendingLastFmToken = null;
    _save(
      state.requireValue.copyWith(
        lastFmApiKey: apiKey.trim(),
        lastFmSecret: secret.trim(),
        lastFmSessionKey: '',
        lastFmUser: '',
      ),
    );
  }

  /// Step one of Last.fm desktop auth: returns the approval page to open.
  Future<Uri> startLastFmAuth() async {
    if (!state.requireValue.hasLastFmKeys) {
      throw StateError('Add a Last.fm API key and secret first.');
    }
    final client = _lastFm();
    final token = await client.getToken();
    _pendingLastFmToken = token;
    return client.authorizeUrl(token);
  }

  /// Step two, after the user approved Studio in the browser.
  Future<void> finishLastFmAuth() async {
    final token = _pendingLastFmToken;
    if (token == null) throw StateError('Start connecting first.');
    final session = await _lastFm().getSession(token);
    _pendingLastFmToken = null;
    _save(
      state.requireValue.copyWith(
        lastFmSessionKey: session.key,
        lastFmUser: session.user,
        lastFmExpired: false,
      ),
    );
  }

  void cancelLastFmAuth() => _pendingLastFmToken = null;

  void disconnectLastFm() {
    _pendingLastFmToken = null;
    _save(
      state.requireValue.copyWith(
        lastFmSessionKey: '',
        lastFmUser: '',
        lastFmExpired: false,
      ),
    );
  }

  Future<void> connectListenBrainz(String token) async {
    token = token.trim();
    if (token.isEmpty) throw const FormatException('Paste your user token.');
    final user = await ListenBrainzClient(
      token: token,
      httpClient: ref.read(scrobbleHttpClientProvider),
    ).validateToken();
    _save(
      state.requireValue.copyWith(
        listenBrainzToken: token,
        listenBrainzUser: user,
        listenBrainzExpired: false,
      ),
    );
  }

  void disconnectListenBrainz() {
    _save(
      state.requireValue.copyWith(
        listenBrainzToken: '',
        listenBrainzUser: '',
        listenBrainzExpired: false,
      ),
    );
  }

  /// A service rejected its saved credentials: drop them and say so.
  void markExpired(String serviceId) {
    switch (serviceId) {
      case 'lastfm':
        _save(
          state.requireValue.copyWith(
            lastFmSessionKey: '',
            lastFmUser: '',
            lastFmExpired: true,
          ),
        );
      case 'listenbrainz':
        _save(
          state.requireValue.copyWith(
            listenBrainzToken: '',
            listenBrainzUser: '',
            listenBrainzExpired: true,
          ),
        );
    }
  }
}

final scrobbleSettingsProvider =
    AsyncNotifierProvider<ScrobbleSettingsNotifier, ScrobbleSettings>(
      ScrobbleSettingsNotifier.new,
    );

List<ScrobbleService> scrobbleServicesFor(
  ScrobbleSettings settings,
  http.Client client,
) {
  return [
    if (settings.lastFmConnected)
      LastFmScrobbleService(
        client: LastFmClient(
          apiKey: settings.effectiveLastFmApiKey,
          secret: settings.effectiveLastFmSecret,
          httpClient: client,
        ),
        sessionKey: settings.lastFmSessionKey,
      ),
    if (settings.listenBrainzConnected)
      ListenBrainzScrobbleService(
        ListenBrainzClient(
          token: settings.listenBrainzToken,
          httpClient: client,
        ),
      ),
  ];
}

final scrobblerProvider = Provider<Scrobbler>((ref) {
  final scrobbler = Scrobbler(
    store: ref.watch(scrobbleQueueStoreProvider),
    onAuthFailure: (id) => scheduleMicrotask(
      () => ref.read(scrobbleSettingsProvider.notifier).markExpired(id),
    ),
  );
  ref.listen(scrobbleSettingsProvider, (_, asyncSettings) {
    if (asyncSettings.hasValue) {
      scrobbler.configure(
        scrobbleServicesFor(
          asyncSettings.requireValue,
          ref.read(scrobbleHttpClientProvider),
        ),
      );
    }
  }, fireImmediately: true);
  ref.onDispose(scrobbler.dispose);
  return scrobbler;
});

/// Feeds playback into the scrobbler. Watched once from the app root.
final scrobbleBridgeProvider = Provider<void>((ref) {
  final scrobbler = ref.watch(scrobblerProvider);
  final tracker = ScrobbleTracker();
  ref.listen(playbackControllerProvider, (_, playback) {
    for (final event in tracker.observe(playback)) {
      unawaited(scrobbler.handle(event));
    }
  });
});
