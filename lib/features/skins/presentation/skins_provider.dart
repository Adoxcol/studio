import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/skins/data/skin_store.dart';
import 'package:studio/features/skins/domain/skin.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';

final skinStoreProvider = Provider<SkinStore>((ref) => MemorySkinStore());

@immutable
class SkinsState {
  const SkinsState({this.skins = const [], this.activeId});

  final List<Skin> skins;
  final String? activeId;

  Skin? get active => skins.where((s) => s.id == activeId).firstOrNull;
}

class SkinsNotifier extends Notifier<SkinsState> {
  @override
  SkinsState build() {
    final store = ref.watch(skinStoreProvider);
    final skins = store.load();
    final active = store.loadActive();
    return SkinsState(
      skins: skins,
      activeId: skins.any((s) => s.id == active) ? active : null,
    );
  }

  /// Validates, installs and applies a skin file's contents.
  Skin import(String source) {
    final skin = Skin.parse(source);
    ref.read(skinStoreProvider).install(skin);
    state = SkinsState(
      skins: [...state.skins.where((s) => s.id != skin.id), skin]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      activeId: state.activeId,
    );
    apply(skin.id);
    return skin;
  }

  /// Switches skin; null returns to the built-in Editorial look.
  void apply(String? id) {
    final skin = state.skins.where((s) => s.id == id).firstOrNull;
    ref.read(skinStoreProvider).saveActive(skin?.id);
    state = SkinsState(skins: state.skins, activeId: skin?.id);
    if (skin?.accentHue case final hue?) {
      ref.read(appearanceProvider.notifier).setCustomHue(hue);
    }
  }

  void remove(String id) {
    ref.read(skinStoreProvider).remove(id);
    final removedActive = state.activeId == id;
    state = SkinsState(
      skins: state.skins.where((s) => s.id != id).toList(),
      activeId: removedActive ? null : state.activeId,
    );
    if (removedActive) ref.read(skinStoreProvider).saveActive(null);
  }

  /// The current look as a skin file: the active skin, or Editorial as a
  /// complete starting point to edit and share.
  Skin exportable() {
    final active = state.active;
    if (active != null) return active;
    final appearance = ref.read(appearanceProvider);
    return Skin(
      name: 'Editorial',
      author: 'Studio',
      accentHue: appearance.mode == AccentMode.custom
          ? appearance.customHue
          : null,
      light: SkinPalette.capture(StudioPalette.light()),
      dark: SkinPalette.capture(StudioPalette.dark()),
    );
  }
}

final skinsProvider = NotifierProvider<SkinsNotifier, SkinsState>(
  SkinsNotifier.new,
);

final activeSkinProvider = Provider<Skin?>(
  (ref) => ref.watch(skinsProvider.select((s) => s.active)),
);
