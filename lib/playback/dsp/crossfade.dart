import 'dart:math' as math;

/// Equal-power crossfade curve. Duration is 0 (off) through [max].
abstract final class Crossfade {
  static const off = Duration.zero;
  static const fiveSeconds = Duration(seconds: 5);
  static const max = Duration(seconds: 15);
  static const maxSeconds = 15;

  static String label(Duration duration) {
    if (duration <= Duration.zero) return 'Off';
    return '${duration.inSeconds}s';
  }

  static Duration fromMilliseconds(int? ms) {
    if (ms == null || ms <= 0) return off;
    return Duration(milliseconds: ms.clamp(0, max.inMilliseconds));
  }

  static Duration fromSeconds(int seconds) {
    if (seconds <= 0) return off;
    return Duration(seconds: seconds.clamp(0, maxSeconds));
  }

  /// [t] is 0 at the start of the fade (outgoing full) and 1 at the end.
  static ({double outgoing, double incoming}) gains(double t) {
    final x = t.clamp(0.0, 1.0) * math.pi / 2;
    return (outgoing: math.cos(x), incoming: math.sin(x));
  }
}
