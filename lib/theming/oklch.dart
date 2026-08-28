import 'dart:math' as math;
import 'dart:ui';

/// OKLCH ↔ sRGB using Björn Ottosson's OKLab matrices.
class Oklch {
  const Oklch(this.l, this.c, this.h);

  /// Lightness, 0–1.
  final double l;

  /// Chroma.
  final double c;

  /// Hue in degrees, 0–360.
  final double h;

  Color toColor() {
    final hue = h * math.pi / 180;
    final a = c * math.cos(hue);
    final b = c * math.sin(hue);

    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

    final l3 = l_ * l_ * l_;
    final m3 = m_ * m_ * m_;
    final s3 = s_ * s_ * s_;

    final r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
    final g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
    final bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

    return Color.fromARGB(
      255,
      _byte(_srgbEncode(r)),
      _byte(_srgbEncode(g)),
      _byte(_srgbEncode(bl)),
    );
  }

  static Oklch fromColor(Color color) {
    final r = _srgbDecode(color.r);
    final g = _srgbDecode(color.g);
    final b = _srgbDecode(color.b);

    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    final l_ = math.pow(l, 1 / 3).toDouble();
    final m_ = math.pow(m, 1 / 3).toDouble();
    final s_ = math.pow(s, 1 / 3).toDouble();

    final labL = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    final labA = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    final labB = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

    final chroma = math.sqrt(labA * labA + labB * labB);
    var hue = math.atan2(labB, labA) * 180 / math.pi;
    if (hue < 0) hue += 360;
    return Oklch(labL, chroma, hue);
  }

  static Color color({
    required double l,
    required double c,
    required double h,
  }) {
    return Oklch(l, c, h).toColor();
  }

  static double _srgbEncode(double linear) {
    final clamped = linear.clamp(0.0, 1.0);
    if (clamped >= 0.0031308) {
      return 1.055 * math.pow(clamped, 1 / 2.4) - 0.055;
    }
    return 12.92 * clamped;
  }

  static double _srgbDecode(double encoded) {
    if (encoded <= 0.04045) return encoded / 12.92;
    return math.pow((encoded + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _byte(double encoded) => (encoded.clamp(0.0, 1.0) * 255.0).round();
}
