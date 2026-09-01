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

  void updateTemplates({
    required String name,
    required String details,
    required String stateLine,
    required String artworkText,
  }) {
    state = state.copyWith(
      nameTemplate: name,
      detailsTemplate: details,
      stateTemplate: stateLine,
      artworkTextTemplate: artworkText,
    );
    ref.read(discordSettingsStoreProvider).save(state);
  }

  void setShowProgress(bool value) {
    state = state.copyWith(showProgress: value);
    ref.read(discordSettingsStoreProvider).save(state);
  }

  void resetTemplates() {
    state = state.copyWith(
      nameTemplate: DiscordSettings.defaultNameTemplate,
      detailsTemplate: DiscordSettings.defaultDetailsTemplate,
      stateTemplate: DiscordSettings.defaultStateTemplate,
      artworkTextTemplate: DiscordSettings.defaultArtworkTextTemplate,
      showProgress: true,
    );
    ref.read(discordSettingsStoreProvider).save(state);
  }
}

final discordSettingsProvider =
    NotifierProvider<DiscordSettingsNotifier, DiscordSettings>(
      DiscordSettingsNotifier.new,
    );
