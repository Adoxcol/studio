import 'package:studio/playback/dsp/replay_gain.dart';

class PlaybackSettings {
  const PlaybackSettings({this.replayGain = ReplayGainMode.off});

  final ReplayGainMode replayGain;

  static const defaults = PlaybackSettings();

  PlaybackSettings copyWith({ReplayGainMode? replayGain}) {
    return PlaybackSettings(replayGain: replayGain ?? this.replayGain);
  }
}
