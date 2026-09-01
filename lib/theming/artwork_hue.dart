import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:studio/theming/oklch.dart';

/// Hue of the most chromatic color in [path], or null if none is usable.
Future<double?> hueFromArtwork(String path) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final scale = longest > 64 ? 64 / longest : 1.0;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, 64),
      targetHeight: (descriptor.height * scale).round().clamp(1, 64),
    );
    image = (await codec.getNextFrame()).image;
    final generator = await PaletteGenerator.fromImage(
      image,
      maximumColorCount: 12,
    );
    final candidates = <Color>[
      if (generator.vibrantColor != null) generator.vibrantColor!.color,
      if (generator.lightVibrantColor != null)
        generator.lightVibrantColor!.color,
      if (generator.darkVibrantColor != null) generator.darkVibrantColor!.color,
      if (generator.dominantColor != null) generator.dominantColor!.color,
      ...generator.colors,
    ];
    Oklch? best;
    for (final color in candidates) {
      final oklch = Oklch.fromColor(color);
      if (oklch.c < 0.04) continue;
      if (best == null || oklch.c > best.c) best = oklch;
    }
    return best?.h;
  } on Object {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Artwork paths are content-addressed. Cache small scalar results, never image
/// handles. Rapid skips keep only one active decode and the latest pending one.
class ArtworkHueCache {
  ArtworkHueCache({this.capacity = 128, this.loader = hueFromArtwork})
    : assert(capacity > 0);
  final int capacity;
  final Future<double?> Function(String) loader;
  final _values = <String, double>{};
  _HueRequest? _active;
  _HueRequest? _pending;
  bool _disposed = false;

  Future<double?> read(String path) {
    if (_disposed) return Future.value(null);
    final cached = _values.remove(path);
    if (cached != null) {
      _values[path] = cached;
      return Future.value(cached);
    }
    if (_active?.path == path) return _active!.done.future;
    if (_pending?.path == path) return _pending!.done.future;
    final request = _HueRequest(path);
    if (_active != null) {
      _pending?.done.complete(null);
      _pending = request;
    } else {
      _active = request;
      unawaited(_load(request));
    }
    return request.done.future;
  }

  Future<void> _load(_HueRequest request) async {
    double? hue;
    try {
      hue = await loader(request.path);
    } on Object {
      // A missing/unreadable image must remain retryable.
    }
    if (!_disposed && hue != null) {
      _values[request.path] = hue;
      while (_values.length > capacity) {
        _values.remove(_values.keys.first);
      }
    }
    request.done.complete(_disposed ? null : hue);
    _active = null;
    final next = _pending;
    _pending = null;
    if (next != null && !_disposed) {
      _active = next;
      unawaited(_load(next));
    }
  }

  void dispose() {
    _disposed = true;
    _values.clear();
    _pending?.done.complete(null);
    _pending = null;
  }
}

class _HueRequest {
  _HueRequest(this.path);
  final String path;
  final done = Completer<double?>();
}
