import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/artist_artwork/presentation/artist_picture_providers.dart';
import 'package:studio/features/artist_artwork/presentation/artist_portrait.dart';
import 'package:studio/theming/studio_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late ArtistPictureRepository repository;
  setUp(
    () => repository = ArtistPictureRepository(
      store: MemoryArtistPictureStore(),
      prepare: (bytes) async => bytes,
    ),
  );
  tearDown(() => repository.dispose());

  Widget app({ArtistImagePicker? picker, Widget? child}) => ProviderScope(
    overrides: [
      artistPictureRepositoryProvider.overrideWithValue(repository),
      if (picker != null) artistImagePickerProvider.overrideWithValue(picker),
    ],
    child: MaterialApp(
      theme: StudioTheme.light(),
      home: Scaffold(
        body:
            child ??
            const Column(
              children: [
                ArtistPortrait(artist: 'Aria'),
                ArtistImageControls(artist: 'Aria'),
              ],
            ),
      ),
    ),
  );

  testWidgets('missing image uses an accessible portrait and image menu', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Aria portrait'), findsOneWidget);
    await tester.tap(find.text('Change image'));
    await tester.pumpAndSettle();
    expect(find.text('Choose from computer…'), findsOneWidget);
    expect(find.text('Try online again'), findsOneWidget);
  });

  testWidgets(
    'choose file sets custom; use automatic and placeholder are explicit',
    (tester) async {
      await tester.pumpWidget(
        app(
          picker: () async => Uint8List.fromList([9]),
          child: const ArtistImageControls(artist: 'Aria'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from computer…'));
      await tester.pumpAndSettle();
      expect((await repository.get('Aria')).isCustom, isTrue);
      expect(find.text('Your image · saved on this device'), findsOneWidget);
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use placeholder'));
      await tester.pumpAndSettle();
      expect((await repository.get('Aria')).hidden, isTrue);
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use automatic image'));
      await tester.pumpAndSettle();
      expect((await repository.get('Aria')).isCustom, isFalse);
      expect((await repository.get('Aria')).hidden, isFalse);
    },
  );

  testWidgets(
    'cancelled picker changes nothing and failed import shows feedback',
    (tester) async {
      var fail = false;
      await tester.pumpWidget(
        app(
          picker: () async {
            if (fail) {
              throw const FormatException('Choose an image smaller than 8 MB.');
            }
            return null;
          },
          child: const ArtistImageControls(artist: 'Aria'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from computer…'));
      await tester.pumpAndSettle();
      expect((await repository.get('Aria')).path, isNull);
      fail = true;
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from computer…'));
      await tester.pumpAndSettle();
      expect(find.text('Choose an image smaller than 8 MB.'), findsOneWidget);
    },
  );

  testWidgets(
    'artist changes while picker is open never assign to the new artist',
    (tester) async {
      final pending = Completer<Uint8List?>();
      final artist = ValueNotifier('Aria');
      addTearDown(artist.dispose);
      await tester.pumpWidget(
        app(
          picker: () => pending.future,
          child: ValueListenableBuilder(
            valueListenable: artist,
            builder: (_, name, _) => ArtistImageControls(artist: name),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from computer…'));
      await tester.pumpAndSettle();
      artist.value = 'Hal';
      await tester.pump();
      pending.complete(Uint8List.fromList([9]));
      await tester.pumpAndSettle();
      expect((await repository.get('Aria')).isCustom, isTrue);
      expect((await repository.get('Hal')).isCustom, isFalse);
    },
  );

  testWidgets(
    'photo credit is readable and portrait controls fit a narrow panel',
    (tester) async {
      final store = MemoryArtistPictureStore();
      store.pictures['aria'] = const ArtistPicture(
        remotePath: 'cached.png',
        credit: PictureCredit(
          author: 'Photo Author',
          license: 'CC BY 4.0',
          pageUrl: 'https://commons.wikimedia.org/wiki/File:Example.jpg',
          licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        ),
      );
      repository.dispose();
      repository = ArtistPictureRepository(store: store);
      await tester.pumpWidget(
        app(
          child: const SizedBox(
            width: 140,
            child: ArtistImageControls(artist: 'Aria'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photo credit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Photo Author'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
