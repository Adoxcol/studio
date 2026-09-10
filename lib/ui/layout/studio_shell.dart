import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/ui/layout/icon_rail.dart';
import 'package:studio/ui/layout/studio_workspace.dart';
import 'package:studio/ui/layout/title_bar.dart';
import 'package:studio/ui/keyboard_shortcuts/studio_keyboard_shortcuts.dart';
import 'package:studio/ui/library_browser/scan_notice.dart';
import 'package:studio/ui/now_playing/player_bar.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/settings/settings_page.dart';

class StudioShell extends ConsumerWidget {
  const StudioShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(studioNavProvider);
    ref.watch(libraryBootstrapProvider);
    ref.watch(artistPicturesBootstrapProvider);
    final playbackMode = ref.watch(playbackModeProvider);
    ref.listen(playbackModeProvider, (_, enabled) {
      unawaited(_setNativeFullscreen(enabled));
    });
    final content = playbackMode
        ? const Scaffold(body: PlaybackModePage())
        : Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      StudioIconRail(
                        selected: destination,
                        onSelect: (next) =>
                            ref.read(studioNavProvider.notifier).select(next),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const StudioTitleBar(),
                            Expanded(
                              child: Stack(
                                children: [
                                  Offstage(
                                    offstage:
                                        destination ==
                                        StudioDestination.settings,
                                    child: const StudioWorkspace(),
                                  ),
                                  if (destination == StudioDestination.settings)
                                    const SettingsPage(),
                                  const Positioned(
                                    right: 20,
                                    bottom: 72,
                                    child: ScanNotice(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const PlayerBar(),
              ],
            ),
          );
    return StudioKeyboardShortcuts(child: content);
  }

  Future<void> _setNativeFullscreen(bool enabled) async {
    try {
      await windowManager.setFullScreen(enabled);
    } catch (_) {
      // Widget tests and unsupported window managers still get the immersive
      // in-app presentation.
    }
  }
}
