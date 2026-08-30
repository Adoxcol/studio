import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/core/desktop/close_preference_store.dart';

final closePreferenceStoreProvider = Provider<ClosePreferenceStore>((ref) {
  return MemoryClosePreferenceStore();
});

class ClosePreferenceNotifier extends Notifier<ClosePreference> {
  @override
  ClosePreference build() => ref.watch(closePreferenceStoreProvider).load();

  void remember(CloseAction action) {
    _write(ClosePreference(ask: false, remember: action));
  }

  void askEveryTime() {
    _write(state.copyWith(ask: true));
  }

  void _write(ClosePreference next) {
    state = next;
    ref.read(closePreferenceStoreProvider).save(next);
  }
}

final closePreferenceProvider =
    NotifierProvider<ClosePreferenceNotifier, ClosePreference>(
      ClosePreferenceNotifier.new,
    );
