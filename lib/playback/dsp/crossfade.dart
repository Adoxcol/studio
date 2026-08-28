import 'dart:math' as math;

/// Equal-power crossfade curve and the durations exposed in Settings.
abstract final class Crossfade {
  static const off = Duration.zero;
  static const twoSeconds = Duration(seconds: 2);
  static const fiveSeconds = Duration(seconds: 5);
  static const eightSeconds = Duration(seconds: 8);

  static const options = [off, twoSeconds, fiveSeconds, eightSeconds];

  static String label(Duration duration) {
    if (duration <= Duration.zero) return 'Off';
    return '${duration.inSeconds}s';
  }

  static Duration fromMilliseconds(int? ms) {
    if (ms == null || ms <= 0) return off;
    for (final option in options) {
      if (option.inMilliseconds == ms) return option;
    }
    return Duration(milliseconds: ms.clamp(0, 12000));
  }

  /// [t] is 0 at the start of the fade (outgoing full) and 1 at the end.
  static ({double outgoing, double incoming}) gains(double t) {
    final x = t.clamp(0.0, 1.0) * math.pi / 2;
    return (outgoing: math.cos(x), incoming: math.sin(x));
  }
}
