part of 'editorial_stage.dart';

class _SpecBlock extends StatelessWidget {
  const _SpecBlock({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.hairlineSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: palette.inkMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialArtistAlbumByline extends ConsumerWidget {
  const _EditorialArtistAlbumByline({
    required this.playback,
    required this.palette,
  });

  final PlaybackUiState playback;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = playback.artist ?? 'Unknown Artist';
    final album = playback.album ?? '';
    final year = playback.year != null && playback.year! > 0
        ? ' (${playback.year})'
        : '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          ref.read(libraryNavigationProvider.notifier).openArtist(artist);
          ref.read(playbackModeProvider.notifier).exit();
          ref
              .read(studioNavProvider.notifier)
              .select(StudioDestination.library);
        },
        child: Text(
          album.isNotEmpty ? '$artist • $album$year' : artist,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: palette.inkMuted,
            fontFamilyFallback: const ['Georgia', 'serif'],
          ),
        ),
      ),
    );
  }
}

class _AudiophileSpecsRow extends StatelessWidget {
  const _AudiophileSpecsRow({required this.playback, required this.palette});

  final PlaybackUiState playback;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    final values = discordTemplateValues(playback);
    final format = values['format'] ?? '';
    final lossless = values['lossless'] ?? '';
    final sampleRate = values['sample_rate'] ?? '';

    final badges = [
      if (format.isNotEmpty)
        '$format ${lossless.isNotEmpty ? lossless : ""}'.trim(),
      if (sampleRate.isNotEmpty) sampleRate,
      'ReplayGain -1.2 dB',
      'Bit-Perfect Engine',
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final badge in badges)
          InkWell(
            onTap: () => showAudioEngineSheet(context),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: palette.hairlineSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: palette.hairline),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: palette.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EditorialActionsRow extends ConsumerWidget {
  const _EditorialActionsRow({
    required this.playback,
    required this.track,
    required this.palette,
  });

  final PlaybackUiState playback;
  final Track? track;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Favorite / Heart
        IconButton(
          tooltip: 'Favorite',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.favorite_border, size: 18, color: palette.inkMuted),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added to Favorites: ${playback.title}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        // Add to Playlist
        if (track != null)
          IconButton(
            tooltip: 'Add to Playlist',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add, size: 20, color: palette.inkMuted),
            onPressed: () {
              showTrackActions(
                context: context,
                ref: ref,
                track: track!,
                position: const Offset(300, 300),
              );
            },
          ),
        // Liner notes / Editorial focus
        IconButton(
          tooltip: 'Liner Notes & Album Details',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.menu_book, size: 18, color: palette.inkMuted),
          onPressed: () {
            ref
                .read(editorialStageModeProvider.notifier)
                .select(PlaybackStageMode.editorialFocus);
          },
        ),
        // Track context menu
        if (track != null)
          TrackActionsButton(track: track!, color: palette.inkMuted),
      ],
    );
  }
}
