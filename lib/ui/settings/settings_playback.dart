part of 'settings_page.dart';

class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection();

  Future<void> _importEqualizer(WidgetRef ref) async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import equalizer',
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json', 'cfg', 'conf'],
    );
    final path = file?.path;
    if (path == null) return;
    try {
      final target = File(path);
      if (await target.length() > 1024 * 1024) {
        throw const FormatException('Choose a file smaller than 1 MB.');
      }
      ref
          .read(playbackSettingsProvider.notifier)
          .importEqualizerText(await target.readAsString());
    } on Object catch (error) {
      debugPrint('Equalizer import failed: $error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final playbackSettings = ref.watch(playbackSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'PLAYBACK & SOUND'),
        const SizedBox(height: 16),
        Text('ReplayGain', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        _ReplayGainRow(
          selected: playbackSettings.replayGain,
          onSelect: (mode) =>
              ref.read(playbackSettingsProvider.notifier).setReplayGain(mode),
        ),
        const SizedBox(height: 8),
        Text(
          "Matches loudness across tracks using each file's ReplayGain tags.",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 24),
        Text('Crossfade', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        _CrossfadeSlider(
          selected: playbackSettings.crossfade,
          onSelect: (duration) => ref
              .read(playbackSettingsProvider.notifier)
              .setCrossfade(duration),
        ),
        const SizedBox(height: 8),
        Text(
          'Overlap the next track with an equal-power fade. Off keeps a hard cut.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 24),
        Text('Equalizer', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        _EqualizerPresetRow(
          selected: playbackSettings.equalizerPreset,
          onSelect: (preset) => ref
              .read(playbackSettingsProvider.notifier)
              .setEqualizerPreset(preset),
          onImport: () => _importEqualizer(ref),
        ),
        const SizedBox(height: 8),
        Text(
          'ISO 10-band graphic EQ. The curve and automatic headroom run in playback’s persistent realtime audio graph, so sliders update smoothly without reopening the track. Import Equalizer APO GraphicEQ or parametric Filter lines (AutoEQ / Peace), or a 10-gain JSON; those curves are mapped onto these bands.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
        ),
        const SizedBox(height: 16),
        _EqualizerBands(
          gains: playbackSettings.activeEqualizerGains,
          onChanged: (index, gain) => ref
              .read(playbackSettingsProvider.notifier)
              .setEqualizerBand(index, gain),
        ),
      ],
    );
  }
}

class _ReplayGainRow extends StatelessWidget {
  const _ReplayGainRow({required this.selected, required this.onSelect});

  final ReplayGainMode selected;
  final ValueChanged<ReplayGainMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in ReplayGainMode.values) ...[
          if (mode != ReplayGainMode.values.first) const SizedBox(width: 24),
          LibraryTextAction(
            label: mode.label,
            onTap: () => onSelect(mode),
            muted: mode != selected,
          ),
        ],
      ],
    );
  }
}

class _CrossfadeSlider extends StatelessWidget {
  const _CrossfadeSlider({required this.selected, required this.onSelect});

  static const _height = 20.0;

  final Duration selected;
  final ValueChanged<Duration> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final seconds = selected.inSeconds.clamp(0, Crossfade.maxSeconds);
    final t = Crossfade.maxSeconds == 0 ? 0.0 : seconds / Crossfade.maxSeconds;
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              void at(double dx) {
                final width = constraints.maxWidth;
                if (width <= 0) return;
                final next = ((dx / width) * Crossfade.maxSeconds)
                    .round()
                    .clamp(0, Crossfade.maxSeconds);
                onSelect(Crossfade.fromSeconds(next));
              }

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: const ValueKey('crossfade-slider'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => at(details.localPosition.dx),
                  onHorizontalDragUpdate: (details) =>
                      at(details.localPosition.dx),
                  child: SizedBox(
                    height: _height,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(height: 2, color: palette.hairlineStrong),
                        FractionallySizedBox(
                          widthFactor: t,
                          child: Container(height: 2, color: palette.accent),
                        ),
                        Align(
                          alignment: Alignment(t * 2 - 1, 0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette.accent,
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
            Crossfade.label(Duration(seconds: seconds)),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _EqualizerPresetRow extends StatelessWidget {
  const _EqualizerPresetRow({
    required this.selected,
    required this.onSelect,
    required this.onImport,
  });

  final EqualizerPreset selected;
  final ValueChanged<EqualizerPreset> onSelect;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        for (final preset in EqualizerPreset.values)
          LibraryTextAction(
            label: preset.label,
            onTap: () => onSelect(preset),
            muted: preset != selected,
          ),
        LibraryTextAction(label: 'Import', onTap: onImport, muted: true),
      ],
    );
  }
}

class _EqualizerBands extends StatelessWidget {
  const _EqualizerBands({required this.gains, required this.onChanged});

  final List<double> gains;
  final void Function(int index, double gain) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < Equalizer.bandsHz.length; i++)
          Expanded(
            child: _EqSlider(
              label: Equalizer.labels[i],
              gain: i < gains.length ? gains[i] : 0,
              onChanged: (gain) => onChanged(i, gain),
            ),
          ),
      ],
    );
  }
}

class _EqSlider extends StatelessWidget {
  const _EqSlider({
    required this.label,
    required this.gain,
    required this.onChanged,
  });

  static const double _height = 88;

  final String label;
  final double gain;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final t =
        ((gain - Equalizer.minGain) / (Equalizer.maxGain - Equalizer.minGain))
            .clamp(0.0, 1.0);
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => onChanged(_gainAt(details.localPosition.dy)),
          onVerticalDragUpdate: (details) =>
              onChanged(_gainAt(details.localPosition.dy)),
          child: SizedBox(
            height: _height,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Align(
                  child: Container(
                    width: 2,
                    height: _height,
                    color: palette.hairlineStrong,
                  ),
                ),
                Align(
                  alignment: Alignment(0, 1 - t * 2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.inkMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  double _gainAt(double dy) {
    final t = (1 - (dy / _height)).clamp(0.0, 1.0);
    return Equalizer.minGain + t * (Equalizer.maxGain - Equalizer.minGain);
  }
}
