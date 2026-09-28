import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_repository.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';
import 'package:studio/features/subsonic/domain/subsonic_models.dart';

/// Credit stored with every portrait taken from the server.
const navidromePictureCredit = PictureCredit(
  author: 'Navidrome',
  license: 'Remote Library',
  pageUrl: '',
  licenseUrl: '',
  source: 'Navidrome',
);

/// The one place Studio copies artist portraits from a Navidrome / Subsonic
/// server into the local artist picture cache.
///
/// There used to be three copies of this loop (on connect, on opening the
/// artists list, and at the end of a scan) with different source order and
/// skip rules, racing each other; which image an artist got depended on which
/// finished first. They all go through [sync] now, one run at a time.
///
/// Servers return the same generic placeholder for every artist without a
/// photo. A portrait whose bytes match another artist's is treated as that
/// placeholder: it is not saved, and one saved earlier is removed, so the
/// online lookup can still find a real photo.
class SubsonicArtistPictureSync {
  SubsonicArtistPictureSync({
    required this.repository,
    required this.fetch,
    this.concurrency = 4,
  }) : assert(concurrency > 0);

  final ArtistPictureRepository repository;

  /// Image bytes for an artist, or null when the server has none.
  final Future<Uint8List?> Function(SubsonicArtist artist) fetch;
  final int concurrency;

  Future<void>? _running;

  /// Artists already tried this session without getting a usable portrait.
  final _tried = <String>{};

  /// Raw-bytes digest -> first artist saved with it this session.
  final _firstWithImage = <String, _Saved>{};
  final _placeholders = <String>{};

  /// Copies portraits for [artists]. A call while another run is in progress
  /// waits for that run instead of starting a second one.
  Future<void> sync(
    List<SubsonicArtist> artists, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) {
    final running = _running;
    if (running != null) return running;
    final run = _sync(artists, onProgress, isCancelled ?? () => false);
    _running = run;
    return run.whenComplete(() {
      _running = null;
    });
  }

  Future<void> _sync(
    List<SubsonicArtist> artists,
    void Function(int done, int total)? onProgress,
    bool Function() isCancelled,
  ) async {
    await _dropSavedPlaceholders(artists);

    final todo = <SubsonicArtist>[];
    for (final artist in artists) {
      final key = artistKey(artist.name);
      if (key.isEmpty || _tried.contains(key) || !_hasSource(artist)) {
        continue;
      }
      if ((await repository.get(artist.name)).needsLookup) todo.add(artist);
    }

    var done = 0;
    onProgress?.call(done, todo.length);
    var next = 0;
    Future<void> worker() async {
      while (next < todo.length && !isCancelled()) {
        final artist = todo[next++];
        try {
          await _syncOne(artist);
        } on Object catch (error) {
          // One bad response must not stop the other artists.
          debugPrint('Navidrome portrait for ${artist.name} failed: $error');
        }
        onProgress?.call(++done, todo.length);
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < todo.length; i++) worker(),
    ]);
  }

  static bool _fromServer(PictureCredit? credit) =>
      credit?.source == navidromePictureCredit.source;

  static bool _fromServerOrLegacy(PictureCredit? credit) =>
      credit == null || _fromServer(credit);

  static bool _hasSource(SubsonicArtist artist) =>
      (artist.coverArtId?.isNotEmpty ?? false) ||
      (artist.artistImageUrl?.isNotEmpty ?? false);

  Future<void> _syncOne(SubsonicArtist artist) async {
    final key = artistKey(artist.name);
    final bytes = await fetch(artist);
    if (bytes == null || bytes.isEmpty) {
      _tried.add(key);
      return;
    }
    final digest = sha256.convert(bytes).toString();
    if (_placeholders.contains(digest)) {
      _tried.add(key);
      return;
    }
    final first = _firstWithImage[digest];
    if (first != null && first.key != key) {
      _placeholders.add(digest);
      _tried
        ..add(key)
        ..add(first.key);
      await first.saved;
      await repository.clearRemote(first.name, when: _fromServer);
      return;
    }
    final saved = repository.saveRemote(
      artist.name,
      bytes,
      credit: navidromePictureCredit,
    );
    _firstWithImage[digest] = _Saved(
      key,
      artist.name,
      saved.catchError((_) {}),
    );
    await saved;
  }

  /// Portraits saved before placeholder detection existed: the same server
  /// image stored for several artists is the placeholder. Credit-less images
  /// came from an older copy of this loop that saved no credit.
  Future<void> _dropSavedPlaceholders(List<SubsonicArtist> artists) async {
    final byPath = <String, List<String>>{};
    for (final artist in artists) {
      final picture = await repository.get(artist.name);
      final path = picture.remotePath;
      final source = picture.credit?.source;
      if (path == null ||
          (source != null && source != navidromePictureCredit.source)) {
        continue;
      }
      byPath.putIfAbsent(path, () => []).add(artist.name);
    }
    for (final names in byPath.values) {
      final keys = names.map(artistKey).toSet();
      if (keys.length < 2) continue;
      for (final name in names) {
        _tried.add(artistKey(name));
        await repository.clearRemote(name, when: _fromServerOrLegacy);
      }
    }
  }
}

class _Saved {
  const _Saved(this.key, this.name, this.saved);
  final String key;
  final String name;
  final Future<void> saved;
}
