import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/theming/artwork_hue.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

void main() {
  test('decode sizes follow display density and reuse resize buckets', () {
    expect(CoverArt.decodeExtent(28, 2), 64);
    expect(CoverArt.decodeExtent(56, 2), 128);
    expect(CoverArt.decodeExtent(57, 2), 128);
    expect(CoverArt.decodeExtent(280, 2), 1024);
    expect(CoverArt.decodeExtent(5000, 3), 2048);
  });

  testWidgets('large non-square artwork decodes small without distortion', (
    tester,
  ) async {
    final dimensions = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('studio-cover-decode');
      try {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.red, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2048, 1024);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        final file = await File(
          '${dir.path}/cover.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        final provider = ResizeImage(
          FileImage(file),
          width: 128,
          height: 128,
          policy: ResizeImagePolicy.fit,
        );
        final result = Completer<Size>();
        final stream = provider.resolve(ImageConfiguration.empty);
        late ImageStreamListener listener;
        listener = ImageStreamListener((info, _) {
          result.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          );
          info.dispose();
          stream.removeListener(listener);
        }, onError: result.completeError);
        stream.addListener(listener);
        final size = await result.future;
        await provider.evict();
        final cacheBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
        final hue = await hueFromArtwork(file.path);
        expect(hue, isNotNull);
        expect(hue, inInclusiveRange(0, 360));
        // Palette extraction must not load a full-resolution FileImage into
        // Flutter's shared image cache.
        expect(
          PaintingBinding.instance.imageCache.currentSizeBytes,
          cacheBytes,
        );
        return size;
      } finally {
        await dir.delete(recursive: true);
      }
    });
    expect(dimensions, const Size(128, 64));
  });
}
