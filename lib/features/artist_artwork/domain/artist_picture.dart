import 'dart:typed_data';

String artistKey(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class ArtistImageRequest {
  const ArtistImageRequest(this.name, {this.albums = const []});
  final String name;
  final List<String> albums;
  String get key => artistKey(name);
  bool get searchable =>
      key.isNotEmpty &&
      !const {'unknown artist', 'various artists', '[unknown]'}.contains(key);
}

class PictureCredit {
  const PictureCredit({
    required this.author,
    required this.license,
    required this.pageUrl,
    required this.licenseUrl,
    this.source = 'Wikimedia Commons',
  });
  final String author;
  final String license;
  final String pageUrl;
  final String licenseUrl;
  final String source;

  Map<String, Object?> toJson() => {
    'author': author,
    'license': license,
    'pageUrl': pageUrl,
    'licenseUrl': licenseUrl,
    'source': source,
  };
  factory PictureCredit.fromJson(Map<String, dynamic> json) => PictureCredit(
    author: json['author'] as String,
    license: json['license'] as String,
    pageUrl: json['pageUrl'] as String,
    licenseUrl: json['licenseUrl'] as String,
    source: json['source'] as String? ?? 'Wikimedia Commons',
  );
}

class DownloadedArtistPicture {
  const DownloadedArtistPicture(this.bytes, this.credit);
  final Uint8List bytes;
  final PictureCredit credit;
}

enum PictureLookupState { idle, searching, missing, failed }

class ArtistPicture {
  const ArtistPicture({
    this.customPath,
    this.remotePath,
    this.credit,
    this.hidden = false,
    this.retryAfter,
    this.lookupState = PictureLookupState.idle,
  });
  final String? customPath;
  final String? remotePath;
  final PictureCredit? credit;
  final bool hidden;
  final DateTime? retryAfter;
  final PictureLookupState lookupState;
  String? get path => hidden ? null : customPath ?? remotePath;
  bool get isCustom => !hidden && customPath != null;
  bool get needsLookup => !hidden && customPath == null && remotePath == null;

  ArtistPicture withLookup(PictureLookupState state, {DateTime? retryAfter}) =>
      ArtistPicture(
        customPath: customPath,
        remotePath: remotePath,
        credit: credit,
        hidden: hidden,
        retryAfter: retryAfter,
        lookupState: state,
      );
}

abstract interface class ArtistPictureLookup {
  /// Null means no unambiguous, usable image. Errors are transient, not misses.
  Future<DownloadedArtistPicture?> fetch(ArtistImageRequest artist);
  void cancel();
  void close();
}

/// Optional scheduling hints; a visible portrait never changes matching rules.
abstract interface class PrioritizedArtistPictureLookup {
  void setPriority(String artist, bool prioritized);
}
