import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/metadata_editor/data/track_metadata_writer.dart';
import 'package:studio/features/metadata_editor/domain/track_metadata_edit.dart';
import 'package:studio/library/database.dart';

import '../helpers/pump_studio.dart';
import '../playback/fake_audio_engine.dart';

void main() {
  late StudioDatabase db;
  late FakeAudioEngine engine;
  late Directory directory;
  late File audio;
  late _FakeWriter writer;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    db = StudioDatabase.memory();
    engine = FakeAudioEngine();
    directory = await Directory.systemTemp.createTemp('studio-metadata-ui-');
    audio = File('${directory.path}${Platform.pathSeparator}song.flac');
    await audio.writeAsBytes([1, 2, 3]);
    writer = _FakeWriter(audio);
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: audio.path,
        title: 'Before',
        artist: const Value('Aria'),
        album: const Value('Blue'),
        genre: const Value('Jazz'),
        year: const Value(2024),
        trackNumber: const Value(1),
      ),
    );
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  testWidgets('previews and persists a supported file edit', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tracks = await db.allTracks();
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: tracks,
        extraOverrides: [trackMetadataWriterProvider.overrideWithValue(writer)],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Before').first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit metadata'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('metadata-editor')), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Before'), 'After');
    await tester.pump();
    expect(find.textContaining('Before  →  After'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('write-metadata')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(writer.written?.title, 'After');
    expect(find.byKey(const ValueKey('metadata-editor')), findsNothing);
    final saved = (await db.allTracks()).single;
    expect(saved.title, 'After');
    expect(saved.artist, 'Aria');
  });
}

class _FakeWriter extends TrackMetadataWriter {
  _FakeWriter(this.file);

  final File file;
  TrackMetadataEdit? written;

  @override
  bool supports(String path) => true;

  @override
  Future<FileStat> write(String path, TrackMetadataEdit edit) async {
    written = edit;
    return file.stat();
  }
}
