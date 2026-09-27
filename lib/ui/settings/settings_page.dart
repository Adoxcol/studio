import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:studio/features/artist_artwork/presentation/fanart_settings.dart';
import 'package:studio/features/library_folders/presentation/library_folders_panel.dart';
import 'package:studio/features/scrobbling/presentation/scrobbling_settings_panel.dart';
import 'package:studio/features/skins/presentation/skins_panel.dart';
import 'package:studio/features/updates/update_provider.dart';
import 'package:studio/core/app_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/core/desktop/close_preference_provider.dart';
import 'package:studio/discord/discord_settings_provider.dart';
import 'package:studio/discord/discord_settings.dart';
import 'package:studio/playback/dsp/crossfade.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

part 'settings_appearance.dart';
part 'settings_playback.dart';
part 'settings_discord.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: ListView(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 28),
          const _UpdatesSection(),
          const SizedBox(height: 32),
          const _AppearanceSection(),
          const SizedBox(height: 32),
          const _PreviewSection(),
          const SizedBox(height: 32),
          const _SectionLabel(text: 'SKINS'),
          const SizedBox(height: 16),
          const SkinsPanel(),
          const SizedBox(height: 32),
          const _LibrarySection(),
          const SizedBox(height: 32),
          const _PlaybackSection(),
          const SizedBox(height: 32),
          const _DiscordSection(),
          const SizedBox(height: 32),
          const _SectionLabel(text: 'SCROBBLING'),
          const SizedBox(height: 16),
          const ScrobblingSettingsPanel(),
          const SizedBox(height: 32),
          const _WindowSection(),
        ],
      ),
    );
  }
}

class _UpdatesSection extends ConsumerWidget {
  const _UpdatesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final service = ref.read(updateServiceProvider);
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(text: 'UPDATES'),
            const SizedBox(height: 16),
            Text('$kAppName $kAppVersion'),
            const SizedBox(height: 6),
            Text(
              state.ready
                  ? 'An update to ${state.version} is ready.'
                  : 'Updates are checked in the background when available.',
              style: TextStyle(color: palette.inkMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton(
                  onPressed: state.checking || state.downloading
                      ? null
                      : () => service.check(),
                  child: Text(
                    state.checking
                        ? 'Checking...'
                        : state.downloading
                        ? 'Downloading...'
                        : 'Check for updates',
                  ),
                ),
                if (state.ready)
                  FilledButton(
                    onPressed: service.restartAndUpdate,
                    child: const Text('Restart and Update'),
                  ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                'Unable to check for updates right now.',
                style: TextStyle(color: palette.inkMuted, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LibrarySection extends ConsumerWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final appearance = ref.watch(appearanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'LIBRARY'),
        const SizedBox(height: 16),
        const LibraryFoldersPanel(embedded: true),
        const SizedBox(height: 24),
        Text('Track layout', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final layout in TrackLayout.values) ...[
              if (layout != TrackLayout.values.first) const SizedBox(width: 24),
              LibraryTextAction(
                label: layout.label,
                onTap: () => ref
                    .read(appearanceProvider.notifier)
                    .setTrackLayout(layout),
                muted: appearance.trackLayout != layout,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Cards show cover, title, artist, and album. List keeps the column table.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 24),
        Text('Cover art', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            LibraryTextAction(
              label: 'Show',
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setShowTrackArtwork(true),
              muted: !appearance.showTrackArtwork,
            ),
            const SizedBox(width: 24),
            LibraryTextAction(
              label: 'Hide',
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setShowTrackArtwork(false),
              muted: appearance.showTrackArtwork,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Hides thumbnails on track cards and the list. Album art in Now Playing is unchanged.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 24),
        Text('Missing covers', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            LibraryTextAction(
              label: 'Download',
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setFetchMissingArtwork(true),
              muted: !appearance.fetchMissingArtwork,
            ),
            const SizedBox(width: 24),
            LibraryTextAction(
              label: 'Local only',
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setFetchMissingArtwork(false),
              muted: appearance.fetchMissingArtwork,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Embedded tags, cover.jpg in the folder, and other tracks on the same album come first. Download fills the rest from iTunes.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 32),
        Text('Artist pictures', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 24,
          children: [
            LibraryTextAction(
              label: 'Fetch automatically',
              muted: !appearance.fetchArtistPictures,
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setFetchArtistPictures(true),
            ),
            LibraryTextAction(
              label: 'Cached / custom only',
              muted: appearance.fetchArtistPictures,
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setFetchArtistPictures(false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Finds photos for all library artists in the background using MusicBrainz, fanart.tv (when configured), TheAudioDB (public free key), and Wikimedia. TheAudioDB requests stay below its 30-per-minute limit. Sends artist names and, for ambiguous matches, album titles; never sends your audio files. Images are cached locally, and your chosen pictures always take priority.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 32),
        const FanartSettingsPanel(),
      ],
    );
  }
}

class _WindowSection extends ConsumerWidget {
  const _WindowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final preference = ref.watch(closePreferenceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'WINDOW'),
        const SizedBox(height: 16),
        Text(
          'When closing the window',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        _ClosePreferenceRow(
          preference: preference,
          onAsk: () =>
              ref.read(closePreferenceProvider.notifier).askEveryTime(),
          onRemember: (action) =>
              ref.read(closePreferenceProvider.notifier).remember(action),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask each time, hide to the tray, or quit. "Don\'t show again" on the close dialog remembers this.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
      ],
    );
  }
}

class _ClosePreferenceRow extends StatelessWidget {
  const _ClosePreferenceRow({
    required this.preference,
    required this.onAsk,
    required this.onRemember,
  });

  final ClosePreference preference;
  final VoidCallback onAsk;
  final ValueChanged<CloseAction> onRemember;

  @override
  Widget build(BuildContext context) {
    final ask = preference.ask;
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        LibraryTextAction(label: 'Ask every time', onTap: onAsk, muted: !ask),
        LibraryTextAction(
          label: 'Hide to tray',
          onTap: () => onRemember(CloseAction.background),
          muted: ask || preference.remember != CloseAction.background,
        ),
        LibraryTextAction(
          label: 'Quit',
          onTap: () => onRemember(CloseAction.quit),
          muted: ask || preference.remember != CloseAction.quit,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette.inkMuted,
        letterSpacing: 1.4,
        fontSize: 11,
      ),
    );
  }
}
