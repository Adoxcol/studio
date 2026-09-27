part of 'settings_page.dart';

class _DiscordSection extends ConsumerWidget {
  const _DiscordSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final settings = ref.watch(discordSettingsProvider);
    final enabled = settings.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'DISCORD'),
        const SizedBox(height: 16),
        Text(
          'Show what is playing',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            LibraryTextAction(
              label: 'On',
              onTap: () =>
                  ref.read(discordSettingsProvider.notifier).setEnabled(true),
              muted: !enabled,
            ),
            const SizedBox(width: 24),
            LibraryTextAction(
              label: 'Off',
              onTap: () =>
                  ref.read(discordSettingsProvider.notifier).setEnabled(false),
              muted: enabled,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Friends see the track, artist, and cover while Discord is running. Off by default.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 18),
        Text('Progress bar', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            LibraryTextAction(
              label: 'Show',
              onTap: () => ref
                  .read(discordSettingsProvider.notifier)
                  .setShowProgress(true),
              muted: !settings.showProgress,
            ),
            const SizedBox(width: 24),
            LibraryTextAction(
              label: 'Hide',
              onTap: () => ref
                  .read(discordSettingsProvider.notifier)
                  .setShowProgress(false),
              muted: settings.showProgress,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('Presence text', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            LibraryTextAction(
              label: 'Customize…',
              onTap: () => _showDiscordTemplateDialog(context, ref, settings),
            ),
            const SizedBox(width: 24),
            LibraryTextAction(
              label: 'Reset',
              onTap: () =>
                  ref.read(discordSettingsProvider.notifier).resetTemplates(),
              muted:
                  settings.nameTemplate ==
                      DiscordSettings.defaultNameTemplate &&
                  settings.detailsTemplate ==
                      DiscordSettings.defaultDetailsTemplate &&
                  settings.stateTemplate ==
                      DiscordSettings.defaultStateTemplate &&
                  settings.artworkTextTemplate ==
                      DiscordSettings.defaultArtworkTextTemplate,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Templates can show tags, filenames, format, bitrate, sample rate, and lossless quality.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
      ],
    );
  }
}

Future<void> _showDiscordTemplateDialog(
  BuildContext context,
  WidgetRef ref,
  DiscordSettings settings,
) async {
  final name = TextEditingController(text: settings.nameTemplate);
  final details = TextEditingController(text: settings.detailsTemplate);
  final stateLine = TextEditingController(text: settings.stateTemplate);
  final artwork = TextEditingController(text: settings.artworkTextTemplate);
  try {
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customize Discord presence'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Put optional text in [brackets]. It disappears when one of its variables is unavailable.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _DiscordTemplateField(label: 'Compact title', controller: name),
                _DiscordTemplateField(label: 'First line', controller: details),
                _DiscordTemplateField(
                  label: 'Second line',
                  controller: stateLine,
                ),
                _DiscordTemplateField(
                  label: 'Artwork hover text',
                  controller: artwork,
                ),
                const SizedBox(height: 8),
                Text(
                  'Variables: {title} {artist} {album} {genre} {year} {filename} {file_stem} {format} {bitrate} {sample_rate} {lossless} {quality} {duration} {status}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  children: [
                    LibraryTextAction(
                      label: 'Default preset',
                      onTap: () {
                        name.text = DiscordSettings.defaultNameTemplate;
                        details.text = DiscordSettings.defaultDetailsTemplate;
                        stateLine.text = DiscordSettings.defaultStateTemplate;
                        artwork.text =
                            DiscordSettings.defaultArtworkTextTemplate;
                      },
                    ),
                    LibraryTextAction(
                      label: 'Quality showcase',
                      onTap: () {
                        name.text = '[{artist} - ]{title}';
                        details.text = '{title}';
                        stateLine.text = '{artist}[ • {quality}]';
                        artwork.text = '{album}[ • {filename}]';
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      ref
          .read(discordSettingsProvider.notifier)
          .updateTemplates(
            name: name.text,
            details: details.text,
            stateLine: stateLine.text,
            artworkText: artwork.text,
          );
    }
  } finally {
    name.dispose();
    details.dispose();
    stateLine.dispose();
    artwork.dispose();
  }
}

class _DiscordTemplateField extends StatelessWidget {
  const _DiscordTemplateField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLength: 256,
        decoration: InputDecoration(labelText: label, counterText: ''),
      ),
    );
  }
}
