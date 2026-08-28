import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/pcm_fifo.dart';

void main() {
  test('closed Windows pipe reads empty without throwing', () async {
    if (!Platform.isWindows) return;
    final fifo = await PcmFifo.create();
    await fifo.close();
    expect(await fifo.read(64), isA<Uint8List>());
    expect(await fifo.read(64), isEmpty);
  });
}
