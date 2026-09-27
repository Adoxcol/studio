import 'package:flutter_riverpod/flutter_riverpod.dart';

class LibraryNavigationRequest {
  const LibraryNavigationRequest({
    this.revision = 0,
    this.artist,
    this.album,
    this.playlistId,
  });

  final int revision;
  final String? artist;
  final String? album;
  final int? playlistId;
}

class LibraryNavigationNotifier extends Notifier<LibraryNavigationRequest> {
  @override
  LibraryNavigationRequest build() => const LibraryNavigationRequest();

  void openArtist(String artist) {
    final name = artist.trim();
    if (name.isEmpty) return;
    state = LibraryNavigationRequest(
      revision: state.revision + 1,
      artist: name,
    );
  }

  void openAlbum({required String artist, required String album}) {
    final artistName = artist.trim();
    final albumName = album.trim();
    if (artistName.isEmpty || albumName.isEmpty) return;
    state = LibraryNavigationRequest(
      revision: state.revision + 1,
      artist: artistName,
      album: albumName,
    );
  }

  void openPlaylist(int id) {
    state = LibraryNavigationRequest(
      revision: state.revision + 1,
      playlistId: id,
    );
  }
}

/// Cross-panel requests into the stateful Library catalogue. The revision makes
/// clicking the same artist twice a fresh navigation request.
final libraryNavigationProvider =
    NotifierProvider<LibraryNavigationNotifier, LibraryNavigationRequest>(
      LibraryNavigationNotifier.new,
    );
