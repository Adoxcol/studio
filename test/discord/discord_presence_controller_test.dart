import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_presence.dart';
import 'package:studio/discord/discord_presence_controller.dart';
import 'package:studio/discord/discord_rpc_client.dart';
import 'package:studio/state/playback_provider.dart';

class FakeDiscordRpcClient implements DiscordRpcClient {
  var connectCount = 0;
  var clearCount = 0;
  var disconnectCount = 0;
  final views = <DiscordPresenceView>[];
  Object? connectError;
  Object? activityError;
  var _live = false;

  @override
  bool get isConnected => _live;

  @override
  Future<void> connect() async {
    if (connectError != null) throw connectError!;
    connectCount++;
    _live = true;
  }

  @override
  Future<void> setActivity(DiscordPresenceView view) async {
    if (activityError != null) throw activityError!;
    views.add(view);
  }

  @override
  Future<void> clear() async {
    clearCount++;
    _live = false;
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _live = false;
  }
}

DiscordPresenceController controllerFor(
  DiscordRpcClient client, {
  DateTime Function()? now,
  Duration retryEvery = const Duration(seconds: 20),
  Duration debounce = Duration.zero,
  DiscordArtworkResolver? artwork,
}) {
  return DiscordPresenceController(
    client: client,
    retryEvery: retryEvery,
    debounce: debounce,
    artwork: artwork,
    now: now,
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 29, 4, 0, 0);
  const playing = PlaybackUiState(
    trackId: 1,
    title: 'Headlines',
    artist: 'Drake',
    playing: true,
    position: Duration.zero,
    duration: Duration(minutes: 4),
  );

  test('does not talk to Discord while the setting is off', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: false, playback: playing);
    expect(client.connectCount, 0);
    expect(client.views, isEmpty);
  });

  test('sets Listening presence when enabled and a track is playing', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: true, playback: playing);
    expect(client.connectCount, 1);
    expect(client.views, hasLength(1));
    expect(client.views.single.details, 'Headlines');
    expect(client.views.single.state, 'Drake');
    expect(client.views.single.name, 'Drake - Headlines');
    expect(client.views.single.buttonLabel, 'Play');
    expect(client.views.single.largeImage, 'studio');
    expect(controller.isConnected, isTrue);
  });

  test('clears when playback stops', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: true, playback: playing);
    await controller.sync(enabled: true, playback: const PlaybackUiState());
    expect(client.clearCount, 1);
    expect(controller.isConnected, isFalse);
  });

  test('clears when the setting is turned off', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: true, playback: playing);
    await controller.sync(enabled: false, playback: playing);
    expect(client.clearCount, 1);
  });

  test('does not resend an unchanged presence', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: true, playback: playing);
    await controller.sync(enabled: true, playback: playing);
    expect(client.views, hasLength(1));
  });

  test('play/pause updates the button without reconnecting', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: true, playback: playing);
    await controller.sync(
      enabled: true,
      playback: playing.copyWith(playing: false),
    );
    expect(client.connectCount, 1);
    expect(client.views, hasLength(2));
    expect(client.views.last.buttonLabel, 'Pause');
    expect(client.views.last.start, isNull);
  });

  test('reconnects after a failed activity write', () async {
    final client = FakeDiscordRpcClient()..activityError = 'Write error.';
    final controller = controllerFor(
      client,
      retryEvery: const Duration(milliseconds: 10),
      now: () => now,
    );
    await controller.sync(enabled: true, playback: playing);
    expect(controller.isConnected, isFalse);
    expect(client.views, isEmpty);
    client.activityError = null;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(client.connectCount, 2);
    expect(client.views, hasLength(1));
    await controller.dispose();
  });

  test(
    'reconnects when Discord dropped the pipe under an unchanged track',
    () async {
      final client = FakeDiscordRpcClient();
      final controller = controllerFor(client, now: () => now);
      await controller.sync(enabled: true, playback: playing);
      await client.disconnect();
      await controller.sync(enabled: true, playback: playing);
      expect(client.connectCount, 2);
      expect(client.views, hasLength(2));
      expect(controller.isConnected, isTrue);
    },
  );

  test('retries after Discord was not running', () async {
    final client = FakeDiscordRpcClient()..connectError = 'no ipc';
    final controller = controllerFor(
      client,
      retryEvery: const Duration(milliseconds: 10),
      now: () => now,
    );
    await controller.sync(enabled: true, playback: playing);
    expect(client.connectCount, 0);
    client.connectError = null;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(client.connectCount, 1);
    expect(client.views, hasLength(1));
    await controller.dispose();
  });

  test('duration arriving later adds the progress bar', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(
      enabled: true,
      playback: playing.copyWith(duration: Duration.zero),
    );
    expect(client.views.single.start, isNull);
    await controller.sync(enabled: true, playback: playing);
    expect(client.views, hasLength(2));
    expect(client.views.last.start, isNotNull);
  });

  test('does not rewrite the pipe when only timestamps drift', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(client, now: () => now);
    await controller.sync(enabled: true, playback: playing);
    await controller.sync(
      enabled: true,
      playback: playing.copyWith(duration: const Duration(minutes: 5)),
    );
    expect(client.views, hasLength(1));
  });

  test('rapid track changes send only the latest presence', () async {
    final client = FakeDiscordRpcClient();
    final controller = controllerFor(
      client,
      now: () => now,
      debounce: const Duration(milliseconds: 30),
    );
    const next = PlaybackUiState(
      trackId: 2,
      title: 'Marvins Room',
      artist: 'Drake',
      playing: true,
      duration: Duration(minutes: 5),
    );
    unawaited(controller.sync(enabled: true, playback: playing));
    unawaited(controller.sync(enabled: true, playback: next));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(client.views, hasLength(1));
    expect(client.views.single.details, 'Marvins Room');
    await controller.dispose();
  });

  test('uploaded cover URL is sent as the large image', () async {
    final client = FakeDiscordRpcClient();
    final artwork = _FakeArtworkResolver()
      ..urls['/covers/take-care.jpg'] = 'https://iili.io/take-care.jpg';
    final controller = controllerFor(client, now: () => now, artwork: artwork);
    await controller.sync(
      enabled: true,
      playback: playing.copyWith(artworkPath: '/covers/take-care.jpg'),
    );
    expect(artwork.calls, 0);
    expect(client.views.single.largeImage, 'https://iili.io/take-care.jpg');
  });
}

class _FakeArtworkResolver implements DiscordArtworkResolver {
  final urls = <String?, String?>{};
  var calls = 0;

  @override
  String? cachedUrl(String? path) => urls[path];

  @override
  Future<String?> urlFor(String? path) async {
    calls++;
    return urls[path];
  }
}
