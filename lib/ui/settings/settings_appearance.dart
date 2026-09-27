part of 'settings_page.dart';

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final appearance = ref.watch(appearanceProvider);
    final hue = ref.watch(resolvedAccentHueProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'APPEARANCE'),
        const SizedBox(height: 16),
        Text('Theme', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final mode in AppThemeMode.values) ...[
              if (mode != AppThemeMode.values.first) const SizedBox(width: 24),
              LibraryTextAction(
                label: mode.label,
                onTap: () =>
                    ref.read(appearanceProvider.notifier).setThemeMode(mode),
                muted: appearance.themeMode != mode,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Dark uses the Editorial Mono night surfaces. System follows the OS.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 24),
        Text('Accent color', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            LibraryTextAction(
              label: 'Auto — from album art',
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setMode(AccentMode.auto),
              muted: appearance.mode != AccentMode.auto,
            ),
            const SizedBox(width: 24),
            LibraryTextAction(
              label: 'Custom',
              onTap: () => ref
                  .read(appearanceProvider.notifier)
                  .setMode(AccentMode.custom),
              muted: appearance.mode != AccentMode.custom,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Named swatches are shortcuts. Drag the hue bar for any accent — chroma and lightness stay the same as Auto.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final seed in AccentSeed.values)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _Swatch(
                  seed: seed,
                  selected:
                      appearance.mode == AccentMode.custom &&
                      seed.matches(appearance.customHue),
                  onTap: () => ref
                      .read(appearanceProvider.notifier)
                      .setCustomHue(seed.hue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _HueSlider(
          hue: appearance.mode == AccentMode.custom
              ? appearance.customHue
              : hue,
          onChanged: (next) =>
              ref.read(appearanceProvider.notifier).setCustomHue(next),
        ),
      ],
    );
  }
}

class _PreviewSection extends ConsumerWidget {
  const _PreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final appearance = ref.watch(appearanceProvider);
    final hue = ref.watch(resolvedAccentHueProvider);
    final playback = ref.watch(
      playbackControllerProvider.select(
        (s) => (
          trackId: s.trackId,
          title: s.title,
          artist: s.artist,
          artworkPath: s.artworkPath,
        ),
      ),
    );
    final previewLabel =
        '${appearance.mode == AccentMode.auto ? 'AUTO' : 'CUSTOM'} · ${AccentSeed.labelFor(hue)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'PREVIEW'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CoverArt(path: playback.artworkPath, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playback.trackId == null
                        ? 'Nocturne in Blue'
                        : playback.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playback.artist ?? 'Aria Solvang',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.inkMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    previewLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.inkMuted,
                      letterSpacing: 1.4,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  static const _height = 20.0;

  final double hue;
  final ValueChanged<double> onChanged;

  static List<Color> _spectrum(Brightness brightness) => [
    for (var h = 0; h <= 360; h += 30)
      StudioPalette.forBrightness(brightness, hue: h.toDouble()).accent,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final brightness = Theme.of(context).brightness;
    final t = (AccentSeed.wrap(hue) / 360).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              void at(double dx) {
                final width = constraints.maxWidth;
                if (width <= 0) return;
                onChanged((dx / width) * 360);
              }

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: const ValueKey('hue-slider'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => at(details.localPosition.dx),
                  onHorizontalDragUpdate: (details) =>
                      at(details.localPosition.dx),
                  child: SizedBox(
                    height: _height,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _spectrum(brightness),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment(t * 2 - 1, 0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: StudioPalette.forBrightness(
                                brightness,
                                hue: hue,
                              ).accent,
                              border: Border.all(color: palette.ink, width: 1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 36,
          child: Text(
            '${AccentSeed.wrap(hue).round()}°',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final AccentSeed seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = StudioPalette.forBrightness(
      Theme.of(context).brightness,
      hue: seed.hue,
    ).accent;
    return Tooltip(
      message: seed.label,
      child: Semantics(
        button: true,
        label: seed.label,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: 28,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? fill : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ColoredBox(color: fill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
