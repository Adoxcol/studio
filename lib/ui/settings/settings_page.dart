import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/core/desktop/close_preference.dart';
import 'package:studio/core/desktop/close_preference_provider.dart';
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
    final previewLabel =
        '${appearance.mode == AccentMode.auto ? 'AUTO' : 'CUSTOM'} · ${AccentSeed.labelFor(hue)}';

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
          Text('Crossfade', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          _CrossfadeSlider(
            selected: ref.watch(playbackSettingsProvider).crossfade,
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
          const SizedBox(height: 32),
          _SectionLabel(text: 'WINDOW'),
          const SizedBox(height: 16),
          Text(
            'When closing the window',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          _ClosePreferenceRow(
            preference: ref.watch(closePreferenceProvider),
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

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hue, required this.onChanged});

  static const _height = 20.0;

  final double hue;
  final ValueChanged<double> onChanged;

  static final _spectrum = [
    for (var h = 0; h <= 360; h += 30)
      StudioPalette.light(hue: h.toDouble()).accent,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
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
                            gradient: LinearGradient(colors: _spectrum),
                          ),
                        ),
                        Align(
                          alignment: Alignment(t * 2 - 1, 0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: StudioPalette.light(hue: hue).accent,
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
