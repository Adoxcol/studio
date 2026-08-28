import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/accent_seed.dart';
import 'package:studio/theming/appearance_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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
    final seed = AccentSeed.nearest(hue);
    final previewLabel =
        '${appearance.mode == AccentMode.auto ? 'AUTO' : 'CUSTOM'} · ${seed.label.toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: ListView(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 28),
          _SectionLabel(text: 'APPEARANCE'),
          const SizedBox(height: 16),
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
            'Every swatch here uses the same tonal formula as the auto engine — same chroma, same lightness, only the hue changes — so any pick stays exactly as clean.',
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
                        AccentSeed.nearest(appearance.customHue) == seed,
                    onTap: () => ref
                        .read(appearanceProvider.notifier)
                        .setCustomHue(seed.hue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionLabel(text: 'PREVIEW'),
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
          const SizedBox(height: 32),
          _SectionLabel(text: 'PLAYBACK & SOUND'),
          const SizedBox(height: 16),
          Text('ReplayGain', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          _ReplayGainRow(
            selected: ref.watch(playbackSettingsProvider).replayGain,
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
          Text('Equalizer', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          _EqualizerPresetRow(
            selected: ref.watch(playbackSettingsProvider).equalizerPreset,
            onSelect: (preset) => ref
                .read(playbackSettingsProvider.notifier)
                .setEqualizerPreset(preset),
          ),
          const SizedBox(height: 16),
          _EqualizerBands(
            gains: ref.watch(playbackSettingsProvider).activeEqualizerGains,
            onChanged: (index, gain) => ref
                .read(playbackSettingsProvider.notifier)
                .setEqualizerBand(index, gain),
          ),
        ],
      ),
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

class _EqualizerPresetRow extends StatelessWidget {
  const _EqualizerPresetRow({required this.selected, required this.onSelect});

  final EqualizerPreset selected;
  final ValueChanged<EqualizerPreset> onSelect;

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
    final fill = StudioPalette.light(hue: seed.hue).accent;
    return Tooltip(
      message: seed.label,
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
    );
  }
}
