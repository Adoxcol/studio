import 'dart:io';

import 'package:drift/drift.dart' show Value;
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
  late _BatchFakeWriter writer;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    db = StudioDatabase.memory();
    engine = FakeAudioEngine();
    directory = await Directory.systemTemp.createTemp('studio-batch-tags-');
    final flac = File('${directory.path}${Platform.pathSeparator}one.flac');
    final ogg = File('${directory.path}${Platform.pathSeparator}two.ogg');
    await flac.writeAsBytes([1]);
    await ogg.writeAsBytes([2]);
    writer = _BatchFakeWriter();
    await db.upsertTracks([
      TracksCompanion.insert(
        locator: flac.path,
        title: 'One',
        artist: const Value('Old artist'),
        trackNumber: const Value(1),
      ),
      TracksCompanion.insert(
        locator: ogg.path,
        title: 'Two',
        artist: const Value('Old artist'),
        trackNumber: const Value(2),
      ),
    ]);
  });

  tearDown(() async {
    engine.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  testWidgets('selection batch-edits writable tracks and reports skipped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: await db.allTracks(),
        extraOverrides: [trackMetadataWriterProvider.overrideWithValue(writer)],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tap(find.text('One'));
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    expect(engine.playCount, 0);
    expect(engine.loadCount, 0);

    await tester.tap(find.text('Edit metadata'));
    await tester.pumpAndSettle();
    expect(find.text('1 writable · 1 will be skipped'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('batch-field-artist')));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Artist credits'),
      'Old artist',
    );
    await tester.pump();
    expect(find.text('Apply to 0 tracks'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('apply-batch-metadata')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Artist credits'),
      'New artist',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('apply-batch-metadata')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Updated 1 of 1 tracks.'), findsOneWidget);
    expect(writer.writes, hasLength(1));
    expect(writer.writes.single.$2.artist, 'New artist');
    final tracks = await db.allTracks();
    expect(
      tracks.firstWhere((track) => track.title == 'One').artist,
      'New artist',
    );
    expect(
      tracks.firstWhere((track) => track.title == 'Two').artist,
      'Old artist',
    );
    expect(tracks.firstWhere((track) => track.title == 'One').trackNumber, 1);
  });

  testWidgets('select all continues after an individual write failure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final extra = File('${directory.path}${Platform.pathSeparator}three.flac');
    await tester.runAsync(() => extra.writeAsBytes([3]));
    await db.upsertTrack(
      TracksCompanion.insert(
        locator: extra.path,
        title: 'Three',
        artist: const Value('Old artist'),
      ),
    );
    writer.failName = 'one.flac';
    await tester.pumpWidget(
      testStudioApp(
        db: db,
        engine: engine,
        tracks: await db.allTracks(),
        extraOverrides: [trackMetadataWriterProvider.overrideWithValue(writer)],
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.text('Edit metadata'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('batch-field-artist')));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Artist credits'),
      'Shared',
    );
    await tester.pump();
    expect(find.text('Apply to 2 tracks'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('apply-batch-metadata')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Updated 1 of 2 tracks.'), findsOneWidget);
    expect(find.textContaining('One: File write failed.'), findsOneWidget);
    final tracks = await db.allTracks();
    expect(
      tracks.firstWhere((track) => track.title == 'One').artist,
      'Old artist',
    );
    expect(
      tracks.firstWhere((track) => track.title == 'Three').artist,
      'Shared',
    );
  });
}

class _BatchFakeWriter extends TrackMetadataWriter {
  final writes = <(String, TrackMetadataEdit)>[];
  String? failName;

  @override
  Future<FileStat> write(
    String path,
    TrackMetadataEdit edit, {
    EmbeddedCoverEdit cover = const EmbeddedCoverEdit.keep(),
  }) async {
    writes.add((path, edit));
    if (failName != null && path.endsWith(failName!)) {
      throw const FileSystemException('Test write failure');
    }
    return File(path).stat();
  }
}
