import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// Log-spaced FFT bands from interleaved float32 PCM.
class SpectrumAnalyzer {
  SpectrumAnalyzer({
    this.fftSize = 2048,
    this.bandCount = 32,
    this.sampleRate = 48000,
    this.hopSize = 1024,
    this.minDb = -90,
    this.maxDb = -25,
    this.lowHz = 40,
    this.highHz = 16000,
    this.attack = 0.45,
    this.release = 0.18,
  })  : _fft = FFT(fftSize),
        _window = Window.hanning(fftSize),
        _bands = List<double>.filled(bandCount, 0),
        _mono = Float64List(fftSize * 2);

  final int fftSize;
  final int bandCount;
  int sampleRate;
  final int hopSize;
  final double minDb;
  final double maxDb;
  final double lowHz;
  final double highHz;
  final double attack;
  final double release;

  final FFT _fft;
  final Float64List _window;
  final List<double> _bands;
  final Float64List _mono;
  var _monoLength = 0;

  List<double> get bands => List<double>.from(_bands);

  void reset() {
    _monoLength = 0;
    for (var i = 0; i < _bands.length; i++) {
      _bands[i] = 0;
    }
  }

  /// Mixes interleaved little-endian float32 PCM to mono and returns a
  /// smoothed band frame when a full FFT window is ready.
  List<double>? addInterleavedFloat32(Uint8List bytes, {int channels = 2}) {
    if (bytes.length < 4) return null;
    final count = bytes.length ~/ 4;
    final data = ByteData.sublistView(bytes);
    final ch = channels < 1 ? 1 : channels;
    List<double>? frame;
    for (var i = 0; i + ch <= count; i += ch) {
      var mix = 0.0;
      for (var c = 0; c < ch; c++) {
        mix += data.getFloat32((i + c) * 4, Endian.little);
      }
      mix /= ch;
      if (_monoLength < _mono.length) {
        _mono[_monoLength++] = mix;
      }
      while (_monoLength >= fftSize) {
        frame = _analyzeWindow();
        final remain = _monoLength - hopSize;
        _mono.setRange(0, remain, _mono, hopSize);
        _monoLength = remain;
      }
    }
    return frame;
  }

  /// First band whose upper edge is above [hz]. Exposed for tests.
  int bandIndexForHz(double hz) {
    final nyquist = sampleRate / 2;
    final top = math.min(highHz, nyquist);
    if (hz <= lowHz) return 0;
    if (hz >= top) return bandCount - 1;
    final t = math.log(hz / lowHz) / math.log(top / lowHz);
    return (t * bandCount).floor().clamp(0, bandCount - 1);
  }

  List<double> _analyzeWindow() {
    final windowed = Float64List(fftSize);
    for (var i = 0; i < fftSize; i++) {
      windowed[i] = _mono[i] * _window[i];
    }
    final mags = _fft.realFft(windowed).discardConjugates().magnitudes();
    final nyquist = sampleRate / 2.0;
    final top = math.min(highHz, nyquist);
    final scale = fftSize / 2.0;
    final next = List<double>.filled(bandCount, 0);
    for (var b = 0; b < bandCount; b++) {
      final loHz = lowHz * math.pow(top / lowHz, b / bandCount).toDouble();
      final hiHz =
          lowHz * math.pow(top / lowHz, (b + 1) / bandCount).toDouble();
      final loBin = math.max(1, (loHz * fftSize / sampleRate).floor());
      final hiBin = math.min(
        mags.length,
        math.max(loBin + 1, (hiHz * fftSize / sampleRate).ceil()),
      );
      var peak = 0.0;
      for (var bin = loBin; bin < hiBin; bin++) {
        final mag = mags[bin] / scale;
        if (mag > peak) peak = mag;
      }
      final db = peak <= 1e-12 ? minDb : 20 * math.log(peak) / math.ln10;
      next[b] = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    }
    for (var i = 0; i < bandCount; i++) {
      final coeff = next[i] > _bands[i] ? attack : release;
      _bands[i] += (next[i] - _bands[i]) * coeff;
    }
    return bands;
  }
}
