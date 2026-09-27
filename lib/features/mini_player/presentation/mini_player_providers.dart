import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/mini_player/data/mini_player_store.dart';
import 'package:studio/features/mini_player/data/mini_window.dart';
import 'package:studio/state/playback_mode_provider.dart';

final miniPlayerStoreProvider = Provider<MiniPlayerStore>(
  (ref) => MemoryMiniPlayerStore(),
);

final miniWindowProvider = Provider<MiniWindow>(
  (ref) => WindowManagerMiniWindow(),
);

@immutable
class MiniPlayerState {
  const MiniPlayerState({this.active = false, this.pinned = true});

  final bool active;

  /// Keep the mini player above other windows.
  final bool pinned;

  MiniPlayerState copyWith({bool? active, bool? pinned}) => MiniPlayerState(
    active: active ?? this.active,
    pinned: pinned ?? this.pinned,
  );
}

class MiniPlayerNotifier extends Notifier<MiniPlayerState> {
  @override
  MiniPlayerState build() =>
      MiniPlayerState(pinned: ref.watch(miniPlayerStoreProvider).loadPinned());

  Future<void> enter() async {
    if (state.active) return;
    if (ref.read(playbackModeProvider)) {
      ref.read(playbackModeProvider.notifier).exit();
    }
    state = state.copyWith(active: true);
    await ref.read(miniWindowProvider).enter(pinned: state.pinned);
  }

  Future<void> exit() async {
    if (!state.active) return;
    state = state.copyWith(active: false);
    await ref.read(miniWindowProvider).exit();
  }

  Future<void> toggle() => state.active ? exit() : enter();

  Future<void> togglePinned() async {
    final pinned = !state.pinned;
    state = state.copyWith(pinned: pinned);
    ref.read(miniPlayerStoreProvider).savePinned(pinned);
    if (state.active) await ref.read(miniWindowProvider).setPinned(pinned);
  }
}

final miniPlayerProvider =
    NotifierProvider<MiniPlayerNotifier, MiniPlayerState>(
      MiniPlayerNotifier.new,
    );
