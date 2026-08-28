/// Local-library data access. Drift/sqlite implementation comes later.
abstract interface class LibraryRepository {
  Future<List<String>> listTrackPaths();
}
