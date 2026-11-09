import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/metadata_editor/data/track_metadata_writer.dart';
import 'package:studio/features/metadata_editor/domain/track_metadata_edit.dart';
import 'package:studio/library/tag_reader.dart';

Uint8List _buildMinimalFlac() {
  final builder = BytesBuilder();
  builder.add('fLaC'.codeUnits);
  // Streaminfo block: type 0, isLast = 1 (0x80), length 34 (0x00, 0x00, 0x22)
  builder.add([0x80, 0x00, 0x00, 34]);
  // 10 bytes: min/max block size & min/max frame size
  builder.add([0x10, 0x00, 0x10, 0x00, 0, 0, 0, 0, 0, 0]);
  // 8 bytes: sampleRate (44100), 2 channels, 16 bits per sample, 441000 total samples
  var val = BigInt.zero;
  val = (val << 20) | BigInt.from(44100);
  val = (val << 3) | BigInt.from(1);
  val = (val << 5) | BigInt.from(15);
  val = (val << 36) | BigInt.from(441000);
  final bd = ByteData(8);
  bd.setUint64(0, val.toInt());
  builder.add(bd.buffer.asUint8List());
  // 16 bytes: MD5 signature
  builder.add(List.filled(16, 0));
  return builder.takeBytes();
}

Uint8List _buildMinimalMp3() {
  final builder = BytesBuilder();
  // ID3v2 header: "ID3", v2.4.0, flags 0, tag size 0
  builder.add('ID3'.codeUnits);
  builder.add([0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
  // MPEG-1 Layer 3 frame sync and header:
  builder.add([0xFF, 0xFB, 0x90, 0x64]);
  builder.add(List.filled(1000, 0));
  return builder.takeBytes();
}

void main() {
  late Directory tempDir;
  const writer = TrackMetadataWriter();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('studio-writer-test-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('supports', () {
    test('returns true for supported audio file extensions', () {
      expect(writer.supports('music/song.mp3'), isTrue);
      expect(writer.supports('music/song.MP3'), isTrue);
      expect(writer.supports('music/song.mp4'), isTrue);
      expect(writer.supports('music/song.m4a'), isTrue);
      expect(writer.supports('music/song.flac'), isTrue);
      expect(writer.supports('music/song.FLAC'), isTrue);
      expect(writer.supports('music/song.wav'), isTrue);
      expect(writer.supports('music/song.ape'), isTrue);
    });

    test(
      'returns false for unsupported extensions or paths without extension',
      () {
        expect(writer.supports('music/song.ogg'), isFalse);
        expect(writer.supports('music/song.opus'), isFalse);
        expect(writer.supports('music/song.txt'), isFalse);
        expect(writer.supports('music/song'), isFalse);
      },
    );
  });

  group('write', () {
    test('throws FileSystemException when audio file does not exist', () async {
      final nonExistentPath = '${tempDir.path}/non_existent.flac';
      expect(
        () => writer.write(
          nonExistentPath,
          const TrackMetadataEdit(title: 'Ghost Song'),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('writes metadata to a FLAC audio file and verifies tags', () async {
      final flacFile = File('${tempDir.path}/test.flac')
        ..writeAsBytesSync(_buildMinimalFlac());

      const edit = TrackMetadataEdit(
        title: 'FLAC Title',
        artist: 'FLAC Artist',
        album: 'FLAC Album',
        genre: 'Classical',
        year: 2024,
        trackNumber: 7,
      );

      final stat = await writer.write(flacFile.path, edit);
      expect(stat.size, greaterThan(0));
      expect(flacFile.existsSync(), isTrue);

      final readTags = const TagReader().read(flacFile);
      expect(readTags.readSucceeded, isTrue);
      expect(readTags.title, 'FLAC Title');
      expect(readTags.artist, 'FLAC Artist');
      expect(readTags.album, 'FLAC Album');
      expect(readTags.genre, 'Classical');
      expect(readTags.year, 2024);
      expect(readTags.trackNumber, 7);
    });

    test('writes metadata to an MP3 audio file and verifies tags', () async {
      final mp3File = File('${tempDir.path}/test.mp3')
        ..writeAsBytesSync(_buildMinimalMp3());

      const edit = TrackMetadataEdit(
        title: 'MP3 Title',
        artist: 'MP3 Artist',
        album: 'MP3 Album',
        genre: 'Electronic',
        year: 2020,
        trackNumber: 2,
      );

      final stat = await writer.write(mp3File.path, edit);
      expect(stat.size, greaterThan(0));
      expect(mp3File.existsSync(), isTrue);

      final readTags = const TagReader().read(mp3File);
      expect(readTags.readSucceeded, isTrue);
      expect(readTags.title, 'MP3 Title');
      expect(readTags.artist, 'MP3 Artist');
      expect(readTags.album, 'MP3 Album');
      expect(readTags.genre, 'Electronic');
      expect(readTags.year, 2020);
      expect(readTags.trackNumber, 2);
    });

    test('handles optional and empty metadata fields cleanly', () async {
      final flacFile = File('${tempDir.path}/sparse.flac')
        ..writeAsBytesSync(_buildMinimalFlac());

      const edit = TrackMetadataEdit(
        title: 'Only Title',
        artist: null,
        album: null,
        genre: null,
        year: null,
        trackNumber: null,
      );

      await writer.write(flacFile.path, edit);
      final readTags = const TagReader().read(flacFile);
      expect(readTags.readSucceeded, isTrue);
      expect(readTags.title, 'Only Title');
      expect(readTags.artist, isNull);
      expect(readTags.album, isNull);
      expect(readTags.genre, isNull);
      expect(readTags.year, isNull);
      expect(readTags.trackNumber, isNull);
    });

    test(
      'supports replacing, keeping, and removing embedded artwork',
      () async {
        final flacFile = File('${tempDir.path}/artwork.flac')
          ..writeAsBytesSync(_buildMinimalFlac());

        final dummyArt = Uint8List.fromList([10, 20, 30, 40, 50, 60]);

        // 1. Replace embedded cover
        await writer.write(
          flacFile.path,
          const TrackMetadataEdit(title: 'Artwork Song', artist: 'Artist 1'),
          cover: EmbeddedCoverEdit.replace(dummyArt, 'image/jpeg'),
        );
        var tags = const TagReader().read(flacFile, getImage: true);
        expect(tags.title, 'Artwork Song');
        expect(tags.artwork, dummyArt);

        // 2. Keep embedded cover across metadata edits
        await writer.write(
          flacFile.path,
          const TrackMetadataEdit(
            title: 'Artwork Song Edited',
            artist: 'Artist 1',
          ),
          cover: const EmbeddedCoverEdit.keep(),
        );
        tags = const TagReader().read(flacFile, getImage: true);
        expect(tags.title, 'Artwork Song Edited');
        expect(tags.artwork, dummyArt);

        // 3. Remove embedded cover
        await writer.write(
          flacFile.path,
          const TrackMetadataEdit(
            title: 'Artwork Song No Cover',
            artist: 'Artist 1',
          ),
          cover: const EmbeddedCoverEdit.remove(),
        );
        tags = const TagReader().read(flacFile, getImage: true);
        expect(tags.title, 'Artwork Song No Cover');
        expect(tags.artwork, isNull);
      },
    );

    test('throws when file content is invalid or corrupted audio', () async {
      final invalidFile = File('${tempDir.path}/corrupted.flac')
        ..writeAsStringSync('not a real audio file content');

      expect(
        () => writer.write(
          invalidFile.path,
          const TrackMetadataEdit(title: 'Should Fail'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
