import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/nav_provider.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/ui/layout/icon_rail.dart';
import 'package:studio/ui/layout/title_bar.dart';
import 'package:studio/ui/library_browser/library_page.dart';
import 'package:studio/ui/now_playing/now_playing_page.dart';
import 'package:studio/ui/now_playing/player_bar.dart';
import 'package:studio/ui/queue/queue_page.dart';
import 'package:studio/ui/settings/settings_page.dart';

class StudioShell extends ConsumerWidget {
  const StudioShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(studioNavProvider);
    return Scaffold(
      body: Row(
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
                Expanded(child: _page(destination)),
                const PlayerBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(StudioDestination destination) {
    return switch (destination) {
      StudioDestination.library => const LibraryPage(),
      StudioDestination.nowPlaying => const NowPlayingPage(),
      StudioDestination.queue => const QueuePage(),
      StudioDestination.settings => const SettingsPage(),
    };
  }
}
