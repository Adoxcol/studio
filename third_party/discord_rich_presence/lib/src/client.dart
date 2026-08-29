import 'dart:io';

import 'package:discord_rich_presence/discord_rich_presence.dart';
import 'package:uuid/uuid.dart';

class Client {
  Client({required this.clientId});

  final String clientId;
  late Transport? _transport;
  void Function()? onClosed;

  Future<void> connect() async {
    _transport = Transport.create(this);
    await _transport?.connect();

    _transport?.events.stream.listen(_rpcMessage);
  }

  Future<void> disconnect() async {
    await _transport?.close();
  }

  Future<void> setActivity(Activity activity) async {
    await _request(
      DiscordCommands.setActivity.name,
      <String, dynamic>{
        'pid': pid,
        'activity': activity.toJson(),
      },
      '',
    );
  }

  Future<void> _request(
      String cmd, Map<String, dynamic> args, String event) async {
    final Uuid uuid = Uuid();
    final String nonce = uuid.v4();

    _transport?.send(<String, Object>{
      'cmd': cmd,
      'args': args,
      'evt': event,
      'nonce': nonce,
    });
  }

  void _rpcMessage(Event message) async {
    switch (message.type) {
      case 'close':
        try {
          await disconnect();
        } catch (_) {}
        onClosed?.call();

      default:
    }
  }
}
