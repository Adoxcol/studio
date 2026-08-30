import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/time_format.dart';
import 'package:studio/features/artist_artwork/presentation/artist_portrait.dart';
import 'package:studio/features/track_details/domain/track_details.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/queue/queue_track_row.dart';

class ArtistDetailPanel extends StatelessWidget {
  const ArtistDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailFrame(
      builder: (details) => [
        LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.centerLeft,
            child: ArtistPortrait(
              artist: details.artist,
              size: constraints.maxWidth.clamp(0.0, 120.0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _Heading(title: details.artist, subtitle: 'Artist · In your library'),
        ArtistImageControls(
          key: ValueKey(details.artist),
          artist: details.artist,
        ),
        const SizedBox(height: 16),
        _Field(label: 'Tracks', value: '${details.artistTracks.length}'),
        _Field(
          label: 'Credited on this track',
          value: details.credits.join(' · '),
        ),
        _Field(label: 'Genres', value: details.genres.join(' · ')),
        const SizedBox(height: 20),
        const _SectionLabel('ALBUMS IN YOUR LIBRARY'),
        for (final section in details.artistAlbums)
          for (final album in section.albums)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CoverArt(path: album.artworkPath, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Heading(
                      title: album.name,
                      subtitle: [
                        section.artist,
                        if (album.year != null) '${album.year}',
                        _count(album.trackCount, 'track'),
                      ].join(' · '),
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class AlbumDetailPanel extends StatelessWidget {
  const AlbumDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailFrame(
      builder: (details) => [
        _ArtworkHeader(
          path: details.track.artworkPath,
          title: details.album,
          subtitle: details.artist,
        ),
        const SizedBox(height: 16),
        _Field(label: 'Year', value: _positive(details.track.year)),
        _Field(
          label: 'Tracks in library',
          value: '${details.albumTracks.length}',
        ),
        _Field(
          label: 'Total length',
          value: formatDurationMs(details.albumDurationMs),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('TRACKS'),
        for (final track in details.albumTracks)
          QueueTrackRow(track: track, current: track.id == details.track.id),
      ],
    );
  }
}

class TrackDetailPanel extends StatelessWidget {
  const TrackDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailFrame(
      builder: (details) => [
        _ArtworkHeader(
          path: details.track.artworkPath,
          title: details.track.title,
          subtitle: details.track.artist ?? 'Unknown artist',
        ),
        const SizedBox(height: 16),
        _Field(label: 'Album', value: details.album),
        _Field(
          label: 'Length',
          value: formatDurationMs(details.track.durationMs),
        ),
        _Field(
          label: 'Track number',
          value: _positive(details.track.trackNumber),
        ),
        _Field(label: 'Year', value: _positive(details.track.year)),
        _Field(label: 'Genre', value: details.track.genre ?? ''),
        _Field(label: 'Source', value: details.track.source),
        _Field(label: 'File / location', value: details.track.locator),
      ],
    );
  }
}

class _DetailFrame extends ConsumerWidget {
  const _DetailFrame({required this.builder});

  final List<Widget> Function(TrackDetails details) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailContext = ref.watch(detailContextProvider);
    final details = detailContext.details;
    final palette = StudioPalette.of(context);
    if (details == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Play a song or right-click a library track and choose View details.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              detailContext.inspected ? 'Selected track' : 'Following playback',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
            ),
            if (detailContext.inspected)
              TextButton(
                onPressed: () =>
                    ref.read(detailSelectionProvider.notifier).followPlayback(),
                child: const Text('Follow playback'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...builder(details),
      ],
    );
  }
}

class _ArtworkHeader extends StatelessWidget {
  const _ArtworkHeader({
    required this.path,
    required this.title,
    required this.subtitle,
  });

  final String? path;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(0.0, 120.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(path: path, size: size),
            const SizedBox(height: 12),
            _Heading(title: title, subtitle: subtitle),
          ],
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: compact ? theme.bodyMedium : theme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.bodySmall?.copyWith(
            color: StudioPalette.of(context).inkMuted,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StudioPalette.of(context).inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(value.trim().isEmpty ? 'Not available' : value),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: StudioPalette.of(context).inkMuted,
      letterSpacing: 1.2,
    ),
  );
}

String _positive(int? value) => value != null && value > 0 ? '$value' : '';
String _count(int count, String noun) => '$count $noun${count == 1 ? '' : 's'}';
