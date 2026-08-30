import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_ids.dart';
import 'package:studio/discord/discord_rpc_client.dart';
import 'package:studio/discord/discord_settings.dart';
import 'package:studio/discord/discord_settings_store.dart';
import 'package:studio/discord/ipc_discord_rpc_client.dart';

final discordSettingsStoreProvider = Provider<DiscordSettingsStore>((ref) {
  return MemoryDiscordSettingsStore();
});

final discordRpcClientProvider = Provider<DiscordRpcClient>((ref) {
  return IpcDiscordRpcClient(applicationId: kDiscordApplicationId);
});

final discordArtworkUploaderProvider = Provider<DiscordArtworkResolver?>(
  (ref) => null,
);

class DiscordSettingsNotifier extends Notifier<DiscordSettings> {
  @override
  DiscordSettings build() => ref.watch(discordSettingsStoreProvider).load();

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    ref.read(discordSettingsStoreProvider).save(state);
  }
}

final discordSettingsProvider =
    NotifierProvider<DiscordSettingsNotifier, DiscordSettings>(
  DiscordSettingsNotifier.new,
);
