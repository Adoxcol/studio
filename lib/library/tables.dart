import 'package:drift/drift.dart';

class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
}

class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get source => text().withDefault(const Constant('local'))();
  TextColumn get locator => text().unique()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  TextColumn get genre => text().nullable()();
  DateTimeColumn get indexedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get artworkPath => text().nullable()();
  IntColumn get fileModifiedMs => integer().nullable()();
  IntColumn get folderId =>
      integer().nullable().references(LibraryFolders, #id)();
}
