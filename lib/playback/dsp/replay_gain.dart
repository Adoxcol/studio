/// mpv `--replaygain` mode. Tags on the file drive the gain; Studio only
/// chooses which set to use.
enum ReplayGainMode {
  off('Off', 'no'),
  track('Track', 'track'),
  album('Album', 'album');

  const ReplayGainMode(this.label, this.mpvValue);

  final String label;

  /// Value for mpv's `replaygain` property.
  final String mpvValue;

  static ReplayGainMode fromName(String? name) {
    for (final mode in values) {
      if (mode.name == name) return mode;
    }
    return ReplayGainMode.off;
  }
}
