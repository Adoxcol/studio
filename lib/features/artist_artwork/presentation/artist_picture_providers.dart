import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/library/database.dart';
import 'package:studio/library/library_query.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/appearance_provider.dart';

// Production supplies disk storage and an online lookup in main. Tests and
// isolated widget previews never accidentally contact a metadata service.
final artistPictureRepositoryProvider = Provider<ArtistPictureRepository>((
  ref,
) {
  final repository = ArtistPictureRepository(store: MemoryArtistPictureStore());
  ref.onDispose(repository.dispose);
  return repository;
});

final artistPictureProvider = StreamProvider.autoDispose
    .family<ArtistPicture, String>((ref, artist) {
      return ref.watch(artistPictureRepositoryProvider).watch(artist);
    });

final artistPicturesBootstrapProvider = Provider<void>((ref) {
  final repository = ref.watch(artistPictureRepositoryProvider);
  final enabled = ref.watch(
    appearanceProvider.select((s) => s.fetchArtistPictures),
  );
  final tracks = ref.watch(libraryTracksProvider).value ?? const <Track>[];
  repository.configure(artistImageRequests(tracks), enabled: enabled);
});

List<ArtistImageRequest> artistImageRequests(List<Track> tracks) {
  final names = <String, String>{};
  final albums = <String, Set<String>>{};
  for (final track in tracks) {
    for (final name in LibraryQuery.creditedArtists(track.artist)) {
      final key = artistKey(name);
      names.putIfAbsent(key, () => name);
      final album = track.album?.trim();
      if (album != null && album.isNotEmpty) (albums[key] ??= {}).add(album);
    }
  }
  return [
    for (final entry in names.entries)
      ArtistImageRequest(
        entry.value,
        albums: (albums[entry.key] ?? {}).toList()..sort(),
      ),
  ];
}

typedef ArtistImagePicker = Future<Uint8List?> Function();
final artistImagePickerProvider = Provider<ArtistImagePicker>(
  (ref) => () async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Choose artist image',
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (selected?.path == null) return null;
    final file = File(selected!.path!);
    if (await file.length() > 8 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 8 MB.');
    }
    return file.readAsBytes();
  },
);
