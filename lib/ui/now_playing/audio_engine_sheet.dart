import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';
import 'package:studio/playback/playback_settings_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

/// Opens the Audio Engine & DSP configuration modal sheet.
void showAudioEngineSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const AudioEngineSheet(),
  );
}

class AudioEngineSheet extends ConsumerWidget {
  const AudioEngineSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(playbackSettingsProvider);
    final notifier = ref.read(playbackSettingsProvider.notifier);
    final playback = ref.watch(playbackControllerProvider);

    final platformEngine = Platform.isWindows
        ? 'WASAPI (Direct Audio)'
        : Platform.isMacOS
        ? 'CoreAudio (Bit-Perfect)'
        : 'PipeWire / ALSA';

    return Container(
      constraints: const BoxConstraints(maxWidth: 580),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1A18) : const Color(0xFFFBF8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF332F2B) : const Color(0xFFE2DDD5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.22),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.tune, size: 18, color: palette.accent),
                  const SizedBox(width: 10),
                  Text(
                    'AUDIO ENGINE & DSP',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: palette.inkMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ReplayGain section
              Text(
                'LOUDNESS MATCHING (REPLAYGAIN)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: palette.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ReplayGainMode>(
                segments: [
                  for (final mode in ReplayGainMode.values)
                    ButtonSegment(value: mode, label: Text(mode.label)),
                ],
                selected: {settings.replayGain},
                onSelectionChanged: (selection) {
                  notifier.setReplayGain(selection.first);
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark
                      ? const Color(0xFF242220)
                      : const Color(0xFFEFEBE4),
                  selectedBackgroundColor: palette.accent.withValues(
                    alpha: 0.18,
                  ),
                  selectedForegroundColor: palette.accent,
                ),
              ),
              const SizedBox(height: 20),

              // Crossfade section
              Row(
                children: [
                  Text(
                    'CROSSFADE TRANSITION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: palette.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    settings.crossfade.inSeconds == 0
                        ? 'Off'
                        : '${settings.crossfade.inSeconds} seconds',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: palette.accent,
                  inactiveTrackColor: isDark
                      ? const Color(0xFF332F2B)
                      : const Color(0xFFDED9CF),
                  thumbColor: palette.accent,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: settings.crossfade.inSeconds.toDouble(),
                  min: 0,
                  max: 15,
                  divisions: 15,
                  onChanged: (val) {
                    notifier.setCrossfade(Duration(seconds: val.round()));
                  },
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final sec in [0, 3, 6, 9, 12])
                    ChoiceChip(
                      label: Text(sec == 0 ? 'Off' : '${sec}s'),
                      selected: settings.crossfade.inSeconds == sec,
                      onSelected: (_) {
                        notifier.setCrossfade(Duration(seconds: sec));
                      },
                      visualDensity: VisualDensity.compact,
                      selectedColor: palette.accent.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: settings.crossfade.inSeconds == sec
                            ? palette.accent
                            : palette.inkMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Equalizer section
              Row(
                children: [
                  Text(
                    'EQUALIZER PROFILE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: palette.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<EqualizerPreset>(
                    value: settings.equalizerPreset,
                    dropdownColor: isDark
                        ? const Color(0xFF242220)
                        : const Color(0xFFF9F5EE),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final preset in EqualizerPreset.values)
                        DropdownMenuItem(
                          value: preset,
                          child: Text(preset.label),
                        ),
                    ],
                    onChanged: (preset) {
                      if (preset != null) notifier.setEqualizerPreset(preset);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Output pipeline badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF23211F)
                      : const Color(0xFFEFEBE3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF332F2B)
                        : const Color(0xFFE0DBD2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.graphic_eq, size: 16, color: palette.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            platformEngine,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                          Text(
                            playback.sampleRateHz != null
                                ? '${(playback.sampleRateHz! / 1000).toStringAsFixed(1)} kHz · Lossless Stream'
                                : 'Bit-Perfect Output Stream',
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: palette.accent,
                        ),
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
