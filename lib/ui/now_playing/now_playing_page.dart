import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/library_providers.dart' show spectrumBandsProvider;
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/lyrics/lyrics_scroller.dart';
import 'package:studio/ui/now_playing/cover_art.dart';
import 'package:studio/ui/visualizer/spectrum_visualizer.dart';

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  static const double artSize = 280;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Queue and the reusable UpNextPanel own queue lookups. This hero needs
    // only current-track metadata, not queue IDs or the library's track map.
    final snapshot = ref.watch(
      playbackControllerProvider.select(
        (s) => (
          title: s.title,
          artist: s.artist,
          artworkPath: s.artworkPath,
          trackId: s.trackId,
        ),
      ),
    );

    return _Hero(
      title: snapshot.title,
      artist: snapshot.artist,
      artworkPath: snapshot.artworkPath,
      hasTrack: snapshot.trackId != null,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.artist,
    required this.artworkPath,
    required this.hasTrack,
  });

  final String title;
  final String? artist;
  final String? artworkPath;
  final bool hasTrack;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const visualizerHeight = 44.0;
        const visualizerBlock = 16 + visualizerHeight + 24;
        const verticalPad = 48.0;
        final titleStyle = Theme.of(context).textTheme.displayLarge;
        final titleLine =
            (titleStyle?.fontSize ?? 44) * (titleStyle?.height ?? 1.05);
        final reserved =
            verticalPad +
            visualizerBlock +
            (hasTrack ? 28.0 : 0.0) +
            titleLine * (hasTrack ? 2 : 1) +
            (artist != null ? 26.0 : 0.0);
        final artSize = [
          NowPlayingPage.artSize,
          (constraints.maxWidth - 64).clamp(64.0, NowPlayingPage.artSize),
          (constraints.maxHeight - reserved).clamp(
            64.0,
            NowPlayingPage.artSize,
          ),
        ].reduce((a, b) => a < b ? a : b);
        final innerHeight = (constraints.maxHeight - verticalPad).clamp(
          0.0,
          double.infinity,
        );
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoverArt(path: artworkPath, size: artSize),
            const SizedBox(height: 16),
            _VisualizerSlot(width: artSize),
            const SizedBox(height: 24),
            if (hasTrack)
              Text(
                'now playing',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.inkMutedAlt,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (hasTrack) const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.displayLarge,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (artist != null) ...[
              const SizedBox(height: 8),
              Text(
                artist!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkMuted,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: hasTrack
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: innerHeight),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: (constraints.maxWidth - 64).clamp(
                      0.0,
                      double.infinity,
                    ),
                    child: header,
                  ),
                ),
              ),
              if (hasTrack) const Expanded(child: LyricsPane()),
            ],
          ),
        );
      },
    );
  }
}

class _VisualizerSlot extends ConsumerWidget {
  const _VisualizerSlot({required this.width});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      playbackControllerProvider.select((s) => s.playing),
    );
    final bands = ref.watch(spectrumBandsProvider).value ?? const [];
    return SpectrumVisualizer(playing: playing, bands: bands, width: width);
  }
}
