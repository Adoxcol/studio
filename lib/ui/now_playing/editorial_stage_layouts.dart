part of 'editorial_stage.dart';

class _SplitStage extends StatelessWidget {
  const _SplitStage({
    super.key,
    required this.playback,
    required this.track,
    required this.coverMode,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final Track? track;
  final PlaybackCoverMode coverMode;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 780;
        final isLowHeight = constraints.maxHeight < 560;

        if (isNarrow) {
          // Narrow viewport: Stack vertically with scroll
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: coverMode == PlaybackCoverMode.fullBleed ? 0 : 20,
              vertical: 16,
            ),
            child: Column(
              children: [
                if (coverMode == PlaybackCoverMode.fullBleed)
                  SizedBox(
                    width: double.infinity,
                    height: 280,
                    child: CoverArt(path: playback.artworkPath, size: 280),
                  )
                else
                  VinylSleeve(
                    artworkPath: playback.artworkPath,
                    size: 180,
                    coverMode: coverMode,
                    track: track,
                  ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _TrackHeader(
                        playback: playback,
                        palette: palette,
                        compact: true,
                      ),
                      const SizedBox(height: 12),
                      _AudiophileSpecsRow(playback: playback, palette: palette),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  height: 300,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: EditorialLyricsPanel(isFullWidth: true),
                  ),
                ),
              ],
            ),
          );
        }

        final leftWidth = (constraints.maxWidth * 0.46).clamp(360.0, 580.0);
        final sleeveSize = isLowHeight
            ? (constraints.maxHeight * 0.38).clamp(160.0, 240.0)
            : (constraints.maxHeight * 0.44).clamp(190.0, 310.0);

        return Row(
          children: [
            // Left Column: Vinyl Sleeve or Full Bleed Artwork & Track Metadata
            if (coverMode == PlaybackCoverMode.fullBleed)
              SizedBox(
                width: leftWidth,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full bleed cover art filling the column edge-to-edge
                    CoverArt(path: playback.artworkPath, size: leftWidth),
                    // Ambient gradient scrim for high readability
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 260,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (isDark
                                      ? const Color(0xFF13110F)
                                      : const Color(0xFFF9F4EE))
                                  .withValues(alpha: 0.95),
                            ],
                            stops: const [0.0, 0.72],
                          ),
                        ),
                      ),
                    ),
                    // Metadata & actions anchored on top of gradient
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '— NOW PLAYING —',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            playback.title.isEmpty
                                ? 'Untitled Track'
                                : playback.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spectral(
                              fontSize: 26,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _EditorialArtistAlbumByline(
                            playback: playback,
                            palette: palette,
                          ),
                          const SizedBox(height: 8),
                          _AudiophileSpecsRow(
                            playback: playback,
                            palette: palette,
                          ),
                          const SizedBox(height: 10),
                          _EditorialActionsRow(
                            playback: playback,
                            track: track,
                            palette: palette,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: leftWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Vinyl Sleeve
                      VinylSleeve(
                        artworkPath: playback.artworkPath,
                        size: sleeveSize,
                        coverMode: coverMode,
                        track: track,
                      ),
                      const SizedBox(height: 20),

                      // "— NOW PLAYING —" tracked micro-headline
                      Text(
                        '— NOW PLAYING —',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Track Title in Editorial Serif
                      Text(
                        playback.title.isEmpty
                            ? 'Untitled Track'
                            : playback.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spectral(
                          fontSize: sleeveSize > 230 ? 30 : 24,
                          height: 1.12,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Artist & Album Byline
                      _EditorialArtistAlbumByline(
                        playback: playback,
                        palette: palette,
                      ),
                      const SizedBox(height: 12),

                      // Audiophile Specs Badges
                      _AudiophileSpecsRow(playback: playback, palette: palette),
                      const SizedBox(height: 14),

                      // Actions Bar (Heart, Add to playlist, Booklet, Details, More)
                      _EditorialActionsRow(
                        playback: playback,
                        track: track,
                        palette: palette,
                      ),
                    ],
                  ),
                ),
              ),

            // Hairline vertical divider separating the stage
            Container(
              width: 1,
              height: double.infinity,
              color: palette.hairline,
            ),

            // Right Column: Synchronized Editorial Lyrics
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                child: EditorialLyricsPanel(isFullWidth: false),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({
    required this.playback,
    required this.palette,
    required this.compact,
  });

  final PlaybackUiState playback;
  final StudioPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '— NOW PLAYING —',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w700,
            color: palette.accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          playback.title.isEmpty ? 'Untitled Track' : playback.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.spectral(
            fontSize: compact ? 22 : 30,
            fontWeight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 4),
        _EditorialArtistAlbumByline(playback: playback, palette: palette),
      ],
    );
  }
}

class _VisualArtStage extends StatelessWidget {
  const _VisualArtStage({
    super.key,
    required this.playback,
    required this.track,
    required this.coverMode,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final Track? track;
  final PlaybackCoverMode coverMode;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (coverMode == PlaybackCoverMode.fullBleed) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Full bleed backdrop cover art
              CoverArt(path: playback.artworkPath, size: constraints.maxWidth),
              // Soft gradient scrim towards bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        (isDark
                                ? const Color(0xFF13110F)
                                : const Color(0xFFF9F4EE))
                            .withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.72],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '— NOW PLAYING —',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playback.title.isEmpty
                          ? 'Untitled Track'
                          : playback.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spectral(
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _EditorialArtistAlbumByline(
                      playback: playback,
                      palette: palette,
                    ),
                    const SizedBox(height: 14),
                    _AudiophileSpecsRow(playback: playback, palette: palette),
                  ],
                ),
              ),
            ],
          );
        }

        final sleeveSize = (constraints.maxHeight * 0.52).clamp(200.0, 420.0);

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VinylSleeve(
                  artworkPath: playback.artworkPath,
                  size: sleeveSize,
                  coverMode: coverMode,
                  track: track,
                ),
                const SizedBox(height: 24),
                Text(
                  '— NOW PLAYING —',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  playback.title.isEmpty ? 'Untitled Track' : playback.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spectral(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                _EditorialArtistAlbumByline(
                  playback: playback,
                  palette: palette,
                ),
                const SizedBox(height: 14),
                _AudiophileSpecsRow(playback: playback, palette: palette),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditorialFocusStage extends ConsumerWidget {
  const _EditorialFocusStage({
    super.key,
    required this.playback,
    required this.track,
    required this.palette,
    required this.isDark,
  });

  final PlaybackUiState playback;
  final Track? track;
  final StudioPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = playback.artist;
    final creditedArtist = artist == null
        ? null
        : LibraryQuery.creditedArtists(artist).firstOrNull;

    final values = discordTemplateValues(playback);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (creditedArtist != null) ...[
                    ArtistPortrait(artist: creditedArtist, size: 120),
                    const SizedBox(width: 24),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EDITORIAL LINER NOTES',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          playback.title,
                          style: GoogleFonts.spectral(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By ${playback.artist ?? "Unknown Artist"} · ${playback.album ?? "Unknown Album"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: palette.inkMuted,
                            fontFamilyFallback: const ['Georgia', 'serif'],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(color: palette.hairline),
              const SizedBox(height: 18),
              Text(
                'AUDIO SPECIFICATIONS & PROVENANCE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _SpecBlock(
                    label: 'Format',
                    value: values['format'] ?? 'Unknown',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Encoding',
                    value: values['lossless']?.isNotEmpty == true
                        ? 'Lossless Stream'
                        : 'Compressed',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Sample Rate',
                    value: values['sample_rate'] ?? '44.1 kHz',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Bitrate',
                    value: values['bitrate'] ?? 'Native',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Year',
                    value: values['year'] ?? 'Unknown',
                    palette: palette,
                  ),
                  _SpecBlock(
                    label: 'Genre',
                    value: playback.genre ?? 'General',
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (playback.locator != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.hairlineSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 16,
                        color: palette.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          playback.locator!,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.inkMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
