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

  /// Equal-power gains scaled to avoid additive headroom overshoot.
  ///
  /// The relative equal-power curve is preserved. Scaling is applied only
  /// while both tracks overlap and their linear gain sum exceeds unity.
  /// Non-finite progress is clamped to an endpoint; NaN selects the start.
  static ({double outgoing, double incoming}) headroomSafeGains(double t) {
    final progress = t.isNaN ? 0.0 : t.clamp(0.0, 1.0).toDouble();
    // Preserve exact endpoint behavior independently of floating-point
    // approximations in sin(pi / 2) and cos(pi / 2).
    if (progress == 0.0) return (outgoing: 1.0, incoming: 0.0);
    if (progress == 1.0) return (outgoing: 0.0, incoming: 1.0);

    final equalPower = gains(progress);

    final linearSum = equalPower.outgoing + equalPower.incoming;
    if (!linearSum.isFinite || linearSum <= 1.0) return equalPower;

    return (
      outgoing: equalPower.outgoing / linearSum,
      incoming: equalPower.incoming / linearSum,
    );
  }
}
