import 'package:studio/playback/dsp/equalizer.dart';
import 'package:studio/playback/dsp/replay_gain.dart';

class PlaybackSettings {
  const PlaybackSettings({
    this.replayGain = ReplayGainMode.off,
    this.equalizerPreset = EqualizerPreset.flat,
    this.equalizerGains = Equalizer.flat,
  });

  final ReplayGainMode replayGain;
  final EqualizerPreset equalizerPreset;
  final List<double> equalizerGains;

  static const defaults = PlaybackSettings();

  List<double> get activeEqualizerGains =>
      Equalizer.gainsFor(equalizerPreset, equalizerGains);

  PlaybackSettings copyWith({
    ReplayGainMode? replayGain,
    EqualizerPreset? equalizerPreset,
    List<double>? equalizerGains,
  }) {
    return PlaybackSettings(
      replayGain: replayGain ?? this.replayGain,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      equalizerGains: equalizerGains ?? this.equalizerGains,
    );
  }
}
