import 'package:flutter/material.dart';
import 'package:studio/state/nav_state.dart';
import 'package:studio/theming/studio_palette.dart';

class StudioIconRail extends StatelessWidget {
  const StudioIconRail({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  static const double width = 64;

  final StudioDestination selected;
  final ValueChanged<StudioDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.hairline)),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            const SizedBox(height: 12),
            _RailButton(
              icon: Icons.library_music_outlined,
              selectedIcon: Icons.library_music,
              tooltip: 'Library',
              selected: selected == StudioDestination.library,
              onTap: () => onSelect(StudioDestination.library),
            ),
            _RailButton(
              icon: Icons.graphic_eq_outlined,
              selectedIcon: Icons.graphic_eq,
              tooltip: 'Now Playing',
              selected: selected == StudioDestination.nowPlaying,
              onTap: () => onSelect(StudioDestination.nowPlaying),
            ),
            _RailButton(
              icon: Icons.fullscreen_outlined,
              selectedIcon: Icons.fullscreen,
              tooltip: 'Playback Mode',
              selected: selected == StudioDestination.playbackMode,
              onTap: () => onSelect(StudioDestination.playbackMode),
            ),
            _RailButton(
              icon: Icons.queue_music_outlined,
              selectedIcon: Icons.queue_music,
              tooltip: 'Queue',
              selected: selected == StudioDestination.queue,
              onTap: () => onSelect(StudioDestination.queue),
            ),
            _RailButton(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              tooltip: 'Artist',
              selected: selected == StudioDestination.artist,
              onTap: () => onSelect(StudioDestination.artist),
            ),
            _RailButton(
              icon: Icons.album_outlined,
              selectedIcon: Icons.album,
              tooltip: 'Album',
              selected: selected == StudioDestination.album,
              onTap: () => onSelect(StudioDestination.album),
            ),
            _RailButton(
              icon: Icons.music_note_outlined,
              selectedIcon: Icons.music_note,
              tooltip: 'Track',
              selected: selected == StudioDestination.track,
              onTap: () => onSelect(StudioDestination.track),
            ),
            const Spacer(),
            _RailButton(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              tooltip: 'Settings',
              selected: selected == StudioDestination.settings,
              onTap: () => onSelect(StudioDestination.settings),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.selectedIcon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final color = selected ? palette.accent : palette.inkMutedAlt;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          width: StudioIconRail.width,
          height: 48,
          child: Icon(selected ? selectedIcon : icon, color: color, size: 22),
        ),
      ),
    );
  }
}
