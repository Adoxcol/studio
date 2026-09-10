import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:studio/library/artwork_store.dart';
import 'package:studio/library/scan_tag_worker.dart';
import 'package:studio/library/tag_reader.dart';

class _ImageReader extends TagReader {
  int reads = 0;
  @override
  ParsedTags read(File file, {bool getImage = false}) {
    reads++;
    return ParsedTags(
      title: file.path,
      artist: 'Artist',
      album: 'Album',
      year: 2026,
      artwork: Uint8List(1024 * 1024),
    );
  }
}

class _GatedStore extends ArtworkStore {
  _GatedStore(super.directory);
  final saves = <Completer<String?>>[];
  @override
  Future<String?> save(Uint8List bytes, {String? mime}) {
    final gate = Completer<String?>();
    saves.add(gate);
    return gate.future;
  }
}

void main() {
  test(
    'each image is saved before reading the next and stripped from results',
    () async {
      final reader = _ImageReader();
      final store = _GatedStore(Directory('unused'));
      final result = readAndCacheTags(['a', 'b', 'c'], reader, store);
      expect(reader.reads, 1);
      for (var i = 0; i < 3; i++) {
        expect(reader.reads, i + 1);
        store.saves[i].complete('cover-$i');
        await Future<void>.delayed(Duration.zero);
      }
      final rows = await result;
      expect(rows.map((row) => row.artworkPath), [
        'cover-0',
        'cover-1',
        'cover-2',
      ]);
      expect(rows.every((row) => row.tags.artwork == null), isTrue);
      expect(
        rows.every(
          (row) => row.tags.artist == 'Artist' && row.tags.year == 2026,
        ),
        isTrue,
      );
    },
  );

  test(
    'worker reuses its isolate for reads, sidecars and saves and closes',
    () async {
      final root = await Directory.systemTemp.createTemp('studio-tag-worker-');
      addTearDown(() => root.delete(recursive: true));
      final worker = await ScanTagWorker.start(p.join(root.path, 'cache'));
      addTearDown(worker.close);
      final badFile = File(p.join(root.path, 'broken.mp3'));
      await badFile.writeAsString('not audio');
      for (var batch = 0; batch < 3; batch++) {
        final rows = await worker.read([badFile.path]);
        expect(rows.single.tags.title, 'broken');
        expect(rows.single.tags.readSucceeded, isFalse);
        expect(rows.single.tags.artwork, isNull);
      }
      final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 3]);
      final path = await worker.save(bytes);
      expect(await File(path!).readAsBytes(), bytes);
      await File(p.join(root.path, 'cover.jpg')).writeAsBytes(bytes);
      expect(await worker.sidecar(badFile.path), path);
      expect(await worker.save(bytes), path);
      await worker.close();
      await expectLater(worker.read([badFile.path]), throwsStateError);
    },
  );

  test('worker propagates IO failures and remains usable', () async {
    final root = await Directory.systemTemp.createTemp(
      'studio-tag-worker-error-',
    );
    addTearDown(() => root.delete(recursive: true));
    final obstruction = File(p.join(root.path, 'cache'));
    await obstruction.writeAsString('not a directory');
    final worker = await ScanTagWorker.start(obstruction.path);
    addTearDown(worker.close);
    await expectLater(
      worker.save(Uint8List.fromList([1])),
      throwsA(isA<Error>()),
    );
    final rows = await worker.read([p.join(root.path, 'missing.mp3')]);
    expect(rows.single.tags.readSucceeded, isFalse);
  });
}
