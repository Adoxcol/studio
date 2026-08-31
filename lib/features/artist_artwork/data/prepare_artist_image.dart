import 'dart:typed_data';
import 'dart:ui' as ui;

/// Validate before publishing a cache entry; decode/resize in the engine, not
/// synchronous Dart pixel loops. Cache one bounded still image, even for GIFs.
Future<Uint8List> prepareArtistImage(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
    throw const FormatException('Choose an image smaller than 8 MB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 40000000) {
      throw const FormatException(
        'Choose an image smaller than 40 megapixels.',
      );
    }
    final scale =
        640 /
        (descriptor.width > descriptor.height
            ? descriptor.width
            : descriptor.height);
    codec = await descriptor.instantiateCodec(
      targetWidth: scale < 1
          ? (descriptor.width * scale).round().clamp(1, 640)
          : null,
      targetHeight: scale < 1
          ? (descriptor.height * scale).round().clamp(1, 640)
          : null,
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const FormatException('This image could not be read.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}
