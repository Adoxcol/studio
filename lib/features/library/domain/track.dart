/// A local audio file in the library.
class Track {
  const Track({required this.path, required this.title, this.artist});

  final String path;
  final String title;
  final String? artist;
}
