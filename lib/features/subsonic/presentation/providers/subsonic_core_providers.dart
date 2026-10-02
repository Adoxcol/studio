import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/subsonic/data/subsonic_client.dart';
import 'package:studio/features/subsonic/data/subsonic_settings_store.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

final subsonicSettingsStoreProvider = Provider<SubsonicSettingsStore>((ref) {
  return MemorySubsonicSettingsStore();
});

class SubsonicConfigNotifier extends Notifier<SubsonicServerConfig?> {
  @override
  SubsonicServerConfig? build() {
    final store = ref.watch(subsonicSettingsStoreProvider);
    return store.load();
  }

  void updateConfig(SubsonicServerConfig? config) {
    state = config;
    ref.read(subsonicSettingsStoreProvider).save(config);
  }
}

final subsonicConfigProvider =
    NotifierProvider<SubsonicConfigNotifier, SubsonicServerConfig?>(
      SubsonicConfigNotifier.new,
    );

final subsonicClientProvider = Provider<SubsonicClient?>((ref) {
  final config = ref.watch(subsonicConfigProvider);
  if (config == null || config.serverUrl.isEmpty) return null;
  final client = SubsonicClient(config: config);
  ref.onDispose(client.dispose);
  return client;
});
