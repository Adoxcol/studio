import 'dart:async';

import 'package:discord_rich_presence/discord_rich_presence.dart';
import 'package:flutter/foundation.dart';
import 'package:studio/discord/discord_presence.dart';
import 'package:studio/discord/discord_rpc_client.dart';

/// Local Discord IPC. A new [Client] is created per connect because the
/// package's disconnect leaves the old instance unusable.
class IpcDiscordRpcClient implements DiscordRpcClient {
  IpcDiscordRpcClient({required this.applicationId})
    : _zone = Zone.current.fork(
        specification: ZoneSpecification(
          handleUncaughtError: (_, _, _, error, stack) {
            debugPrint('Discord IPC: $error\n$stack');
          },
        ),
      );

  final String applicationId;
  final Zone _zone;
  Client? _client;

  @override
  Future<void> connect() => _run(() async {
    await _dropClient();
    final client = Client(clientId: applicationId);
    await client.connect();
    _client = client;
    // Success is otherwise silent: a write into a pipe Discord has stopped
    // reading from (e.g. it hung, or bound the wrong instance) can succeed
    // at the OS level with no exception, so without this a "connected fine
    // but nothing shows on Discord" report leaves no trace either way.
    debugPrint('Discord IPC: connected');
  });

  @override
  Future<void> setActivity(DiscordPresenceView view) => _run(() async {
    final client = _client;
    if (client == null) {
      throw StateError('Discord RPC is not connected');
    }
    await client.setActivity(
      _StudioActivity(
        name: view.name,
        type: ActivityType.listening,
        details: view.details,
        state: view.state,
        timestamps: view.start == null
            ? null
            : ActivityTimestamps(start: view.start, end: view.end),
        assets: ActivityAssets(
          largeImage: view.largeImage,
          largeText: view.album,
          smallImage: view.smallImageKey,
          smallText: view.smallImageText,
        ),
        buttons: [
          {'label': view.buttonLabel, 'url': view.buttonUrl},
        ],
      ),
    );
    debugPrint('Discord IPC: sent "${view.details}" (${view.state ?? '–'})');
  });

  @override
  Future<void> clear() => disconnect();

  @override
  Future<void> disconnect() => _run(_dropClient);

  Future<void> _dropClient() async {
    final client = _client;
    _client = null;
    if (client == null) return;
    try {
      await client.disconnect();
    } on Object catch (error, stack) {
      debugPrint('Discord IPC disconnect: $error\n$stack');
    }
    // Extra margin on top of the now-awaited pipe close (see
    // third_party/discord_rich_presence): Windows only allows one client on
    // the named pipe at a time, and a reconnect issued the instant close()
    // returns has intermittently raced the OS actually releasing the handle.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  /// Catches anything the package still throws asynchronously (e.g. from its
  /// internal read loop) so a dead pipe can't crash the app.
  Future<void> _run(Future<void> Function() action) {
    final done = Completer<void>();
    _zone.run(() {
      unawaited(action().then(done.complete, onError: done.completeError));
    });
    return done.future;
  }
}

/// Extra SET_ACTIVITY fields the package's [Activity] does not serialize.
class _StudioActivity extends Activity {
  _StudioActivity({
    required super.name,
    super.details,
    super.state,
    super.type,
    super.timestamps,
    super.assets,
    this.buttons,
  });

  final List<Map<String, String>>? buttons;

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['status_display_type'] = 0;
    json.remove('timestamps');
    final stamps = discordTimestampsPayload(
      start: timestamps?.start,
      end: timestamps?.end,
    );
    if (stamps != null) json['timestamps'] = stamps;
    final payload = buttons;
    if (payload != null && payload.isNotEmpty) {
      json['buttons'] = payload;
    }
    return json;
  }
}
