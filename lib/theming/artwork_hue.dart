import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:studio/core/network_artwork.dart';
import 'package:studio/theming/oklch.dart';

/// Hue of the most chromatic color in [path], or null if none is usable.
/// [path] is a local file or remote (Navidrome) artwork, which is read
/// through [NetworkArtworkCache] like the cover shown on screen.
Future<double?> hueFromArtwork(
  String path, {
  NetworkArtworkCache? network,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = _isRemote(path)
        ? await ui.ImmutableBuffer.fromUint8List(
            await (network ?? NetworkArtworkCache.instance).bytes(path),
          )
        : await ui.ImmutableBuffer.fromFilePath(path);
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
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return await hueFromRgba(data.buffer.asUint8List());
  } on Object {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

bool _isRemote(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Hue of the most chromatic cluster in raw RGBA [pixels], or null when every
/// cluster is near-grey. Quantizes to a handful of clusters first so a few
/// stray pixels cannot outvote the artwork's actual colors.
@visibleForTesting
Future<double?> hueFromRgba(Uint8List pixels) async {
  final argb = <int>[
    for (var i = 0; i + 3 < pixels.length; i += 4)
      if (pixels[i + 3] >= 128)
        0xff000000 | pixels[i] << 16 | pixels[i + 1] << 8 | pixels[i + 2],
  ];
  if (argb.isEmpty) return null;
  final clusters = await QuantizerCelebi().quantize(argb, 12);
  Oklch? best;
  for (final color in clusters.colorToCount.keys) {
    final oklch = Oklch.fromColor(Color(color));
    if (oklch.c < 0.04) continue;
    if (best == null || oklch.c > best.c) best = oklch;
  }
  return best?.h;
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
    // Remote covers are signed per request; key them by the image instead so
    // every track of an album shares one result.
    final key = _isRemote(path) ? stableArtworkKey(path) : path;
    final cached = _values.remove(key);
    if (cached != null) {
      _values[key] = cached;
      return Future.value(cached);
    }
    if (_active?.key == key) return _active!.done.future;
    if (_pending?.key == key) return _pending!.done.future;
    final request = _HueRequest(key, path);
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
      _values[request.key] = hue;
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
  _HueRequest(this.key, this.path);
  final String key;
  final String path;
  final done = Completer<double?>();
}
