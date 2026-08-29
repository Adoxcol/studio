import 'package:studio/discord/discord_presence.dart';

/// IPC (or a test double) that talks to a running Discord desktop client.
abstract class DiscordRpcClient {
  bool get isConnected;
  Future<void> connect();
  Future<void> setActivity(DiscordPresenceView view);
  Future<void> clear();
  Future<void> disconnect();
}
