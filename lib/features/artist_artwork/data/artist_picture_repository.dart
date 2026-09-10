import 'dart:async';
import 'dart:typed_data';

import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_store.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/data/prepare_artist_image.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

/// Owns background work independently of playback and widget lifetimes.
/// Work is bounded, prioritized, deduplicated, and cancellable. Manual mutations never
/// wait on a network lock; a late result can only fill the separate remote slot.
class ArtistPictureRepository {
  ArtistPictureRepository({
    required this.store,
    this.lookup,
    this.log = const ArtistPictureLog(),
    this.maxConcurrentLookups = 4,
    Future<Uint8List> Function(Uint8List)? prepare,
    DateTime Function()? clock,
  }) : assert(maxConcurrentLookups > 0),
       _prepare = prepare ?? prepareArtistImage,
       _clock = clock ?? DateTime.now;
  final ArtistPictureStore store;
  final ArtistPictureLookup? lookup;
  final ArtistPictureLog log;
  final int maxConcurrentLookups;
  final Future<Uint8List> Function(Uint8List) _prepare;
  final DateTime Function() _clock;
  final _cache = <String, ArtistPicture>{};
  final _loads = <String, Future<ArtistPicture>>{};
  final _writes = <String, Future<void>>{};
  final _changes = StreamController<String>.broadcast(sync: true);
  final _library = <String, ArtistImageRequest>{};
  final _queue = <String, ArtistImageRequest>{};
  Timer? _retry;
  bool _enabled = false;
  bool _disposed = false;
  bool _refreshing = false;
  int _refreshEpoch = 0;
  final _active = <String>{};
  final _visible = <String, int>{};
  final _retryAfter = <String, DateTime>{};
  final _failures = <String, int>{};
  int _generation = 0;

  Future<ArtistPicture> get(String artist) {
    final key = artistKey(artist);
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _loads.putIfAbsent(
      key,
      () => Future<ArtistPicture>.sync(() => store.load(key))
          .then((value) {
            _cache[key] = value;
            if (value.hidden) {
              log(
                'Using selected placeholder; automatic lookup skipped.',
                artist: artist,
              );
            } else if (value.isCustom) {
              log('Cache hit: using your custom image.', artist: artist);
            } else if (value.remotePath != null) {
              log('Cache hit: using downloaded image.', artist: artist);
            } else if (value.retryAfter != null &&
                _clock().isBefore(value.retryAfter!)) {
              log(
                'Cached ${value.lookupState.name}; retry after ${value.retryAfter!.toLocal().toIso8601String()}.',
                artist: artist,
              );
            }
            return value;
          })
          // Run cleanup after the map entry is installed, even when a store throws
          // synchronously. A failed read must never stay memoized forever.
          .whenComplete(() {
            _loads.remove(key);
          }),
    );
  }

  Stream<ArtistPicture> watch(String artist) => Stream.multi((controller) {
    final key = artistKey(artist);
    _visible[key] = (_visible[key] ?? 0) + 1;
    final prioritized = switch (lookup) {
      final PrioritizedArtistPictureLookup value => value,
      _ => null,
    };
    prioritized?.setPriority(key, true);
    if (_visible[key] == 1 && _library.containsKey(key)) {
      log('Visible portrait prioritized.', artist: artist);
      _queue[key] = _library[key]!;
      unawaited(_run());
    }
    // Subscribe before loading so fast imports/downloads cannot be missed.
    var revision = 0;
    final sub = _changes.stream.where((changed) => changed == key).listen((_) {
      revision++;
      controller.add(_cache[key]!);
    }, onDone: controller.close);
    final initialRevision = revision;
    get(key).then((value) {
      if (revision == initialRevision) controller.add(value);
    }, onError: controller.addError);
    controller.onCancel = () {
      final count = (_visible[key] ?? 1) - 1;
      if (count <= 0) {
        _visible.remove(key);
        prioritized?.setPriority(key, false);
      } else {
        _visible[key] = count;
      }
      return sub.cancel();
    };
  });

  void configure(
    Iterable<ArtistImageRequest> artists, {
    required bool enabled,
  }) {
    if (_disposed) return;
    final previousKeys = _library.keys.toSet();
    _library
      ..clear()
      ..addEntries(
        artists.where((a) => a.searchable).map((a) => MapEntry(a.key, a)),
      );
    if (_enabled != enabled) {
      _enabled = enabled;
      _generation++;
      if (!enabled) lookup?.cancel();
      log(
        enabled
            ? 'Background fetching enabled.'
            : 'Background fetching paused; cancelling active lookup. Saved images are kept.',
      );
    }
    if (previousKeys.length != _library.length ||
        !_library.keys.every(previousKeys.contains)) {
      log('Library contains ${_library.length} searchable artists.');
    }
    _queue.removeWhere((key, _) => !_library.containsKey(key));
    _retryAfter.removeWhere((key, _) => !_library.containsKey(key));
    _failures.removeWhere((key, _) => !_library.containsKey(key));
    _retry?.cancel();
    if (!_enabled || lookup == null) {
      _queue.clear();
      return;
    }
    for (final entry in _library.entries) {
      if (!_active.contains(entry.key)) _queue[entry.key] = entry.value;
    }
    unawaited(_run());
  }

  Future<void> setCustom(String artist, Uint8List bytes) async {
    final path = await store.saveImage(await _prepare(bytes));
    await _mutate(
      artistKey(artist),
      (old) => ArtistPicture(
        customPath: path,
        remotePath: old.remotePath,
        credit: old.credit,
      ),
    );
    log(
      'Custom image saved; it takes priority over downloads.',
      artist: artist,
    );
  }

  /// Changing providers invalidates only negative results, never saved images.
  /// Keep the repository alive so widgets and manual imports retain ownership.
  Future<void> refreshSources() async {
    _generation++;
    final epoch = ++_refreshEpoch;
    _refreshing = true;
    lookup?.cancel();
    _retry?.cancel();
    try {
      await Future.wait(_loads.values.toList());
      for (final key in _cache.keys.toList()) {
        if (_disposed || epoch != _refreshEpoch) return;
        await _mutate(
          key,
          (latest) => latest.needsLookup
              ? latest.withLookup(PictureLookupState.idle)
              : latest,
        );
      }
    } finally {
      if (epoch == _refreshEpoch) _refreshing = false;
      if (!_disposed && epoch == _refreshEpoch) {
        // Provider cooldowns live in the lookup and survive this refresh.
        _retryAfter.clear();
        for (final entry in _library.entries) {
          _queue[entry.key] = entry.value;
        }
        log(
          'Image sources changed; retrying missing portraits. Saved images are kept.',
        );
        unawaited(_run());
      }
    }
  }

  Future<void> hide(String artist) async {
    await _mutate(
      artistKey(artist),
      (old) => ArtistPicture(
        customPath: old.customPath,
        remotePath: old.remotePath,
        credit: old.credit,
        hidden: true,
      ),
    );
    log('Placeholder selected; automatic lookup skipped.', artist: artist);
  }

  Future<void> useAutomatic(String artist) async {
    await _mutate(
      artistKey(artist),
      (old) => ArtistPicture(remotePath: old.remotePath, credit: old.credit),
    );
    log('Switched to automatic image.', artist: artist);
    retry(artist);
  }

  void retry(String artist) {
    final key = artistKey(artist);
    if (!_enabled || _disposed || _active.contains(key) || lookup == null) {
      return;
    }
    _retryAfter.remove(key);
    final old = _cache[key];
    if (old != null && old.needsLookup) {
      _publish(key, old.withLookup(PictureLookupState.idle));
    }
    final request = _library[key];
    if (request != null) {
      _queue[key] = request;
      log('Manual retry queued.', artist: request.name);
      unawaited(_run());
    }
  }

  Future<void> _mutate(
    String key,
    ArtistPicture Function(ArtistPicture) change,
  ) {
    final previous = _writes[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final old = await get(key);
      if (_disposed) return;
      final next = change(old);
      await store.save(key, next);
      _publish(key, next);
    });
    // Failure must reach the caller, but not poison subsequent writes.
    _writes[key] = operation.then((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  void _publish(String key, ArtistPicture picture) {
    if (_disposed) return;
    _cache[key] = picture;
    _changes.add(key);
  }

  Future<void> _run() async {
    if (_refreshing || !_enabled || _disposed || lookup == null) return;
    _retry?.cancel();
    while (_active.length < maxConcurrentLookups) {
      String? next;
      for (final key in _queue.keys) {
        if (_active.contains(key) ||
            _retryAfter[key]?.isAfter(_clock()) == true) {
          continue;
        }
        next ??= key;
        if (_visible.containsKey(key)) {
          next = key;
          break;
        }
      }
      if (next == null) break;
      // Reserve one worker for newly visible artists rather than filling every
      // slot with background requests that may be waiting on a slow provider.
      if (!_visible.containsKey(next) &&
          _active.length >=
              (maxConcurrentLookups - 1).clamp(1, maxConcurrentLookups)) {
        break;
      }
      final request = _queue.remove(next)!;
      _active.add(next);
      unawaited(_fetch(request));
    }
    _scheduleRetry();
  }

  Future<void> _fetch(ArtistImageRequest request) async {
    final key = request.key;
    final generation = _generation;
    var stage = 'reading cache';
    try {
      final old = await get(key);
      if (!_enabled || _disposed || generation != _generation) return;
      if (!old.needsLookup ||
          (old.retryAfter != null && _clock().isBefore(old.retryAfter!))) {
        return;
      }
      _publish(key, old.withLookup(PictureLookupState.searching));
      stage = 'online lookup';
      log(
        'Searching online (${_queue.length} artists queued).',
        artist: request.name,
      );
      final downloaded = await lookup!.fetch(request);
      if (_disposed ||
          generation != _generation ||
          !_library.containsKey(key)) {
        log(
          'Lookup cancelled or artist removed; result ignored.',
          artist: request.name,
        );
        return;
      }
      stage = 'validating and caching image';
      Uint8List? prepared;
      if (downloaded != null) {
        try {
          prepared = await _prepare(downloaded.bytes);
        } on Object {
          throw const FormatException(
            'Downloaded artist image could not be decoded',
          );
        }
      }
      final path = prepared == null ? null : await store.saveImage(prepared);
      if (_disposed || generation != _generation) return;
      await _mutate(
        key,
        (latest) => ArtistPicture(
          customPath: latest.customPath,
          hidden: latest.hidden,
          remotePath: latest.remotePath ?? path,
          credit: latest.remotePath != null
              ? latest.credit
              : downloaded?.credit,
          lookupState: path == null
              ? PictureLookupState.missing
              : PictureLookupState.idle,
          retryAfter: path == null
              ? _clock().add(const Duration(days: 7))
              : null,
        ),
      );
      if (downloaded == null) {
        log(
          'No usable online photo (miss cached for 7 days); your image/placeholder is unchanged.',
          artist: request.name,
        );
      } else {
        final chosen = _cache[key]!;
        log(
          'Downloaded and cached ${downloaded.bytes.length} bytes (${downloaded.credit.license}).${chosen.isCustom
              ? ' Your custom image remains selected.'
              : chosen.hidden
              ? ' Your placeholder remains selected.'
              : ''}',
          artist: request.name,
        );
      }
      _failures.remove(key);
      _retryAfter.remove(key);
    } on Object catch (error) {
      if (_disposed || generation != _generation) {
        log('Lookup cancelled.', artist: request.name);
        return;
      }
      log('Failed while $stage: $error', artist: request.name);
      final count = ((_failures[key] ?? 0) + 1).clamp(1, 6);
      _failures[key] = count;
      final deadline =
          error is ArtistServiceException && error.retryAfter != null
          ? error.retryAfter!
          : _clock().add(
              error is FormatException
                  ? const Duration(hours: 1)
                  : Duration(seconds: (30 * (1 << (count - 1))).clamp(30, 900)),
            );
      _retryAfter[key] = deadline;
      // Failed disk reads never overwrite an unreadable custom-image manifest.
      final old = _cache[key];
      if (old != null) {
        try {
          await _mutate(
            key,
            (latest) => latest.withLookup(
              PictureLookupState.failed,
              retryAfter: deadline,
            ),
          );
        } on Object catch (cacheError) {
          log(
            'Could not persist retry state: $cacheError',
            artist: request.name,
          );
          _publish(
            key,
            (_cache[key] ?? old).withLookup(
              PictureLookupState.failed,
              retryAfter: deadline,
            ),
          );
        }
      }
      log(
        'Artist deferred until ${deadline.toLocal().toIso8601String()}; continuing other artists and sources.',
        artist: request.name,
      );
    } finally {
      if (!_disposed &&
          _cache[key]?.lookupState == PictureLookupState.searching) {
        _publish(key, _cache[key]!.withLookup(PictureLookupState.idle));
        if (_enabled && _library.containsKey(key)) {
          _queue[key] = _library[key]!;
        }
      }
      _active.remove(key);
      if (!_disposed) unawaited(_run());
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (_disposed || _refreshing || !_enabled || lookup == null) return;
    DateTime? next;
    for (final key in _library.keys) {
      if (_active.contains(key)) continue;
      final picture = _cache[key];
      if (picture != null && !picture.needsLookup) continue;
      final candidate = _retryAfter[key] ?? picture?.retryAfter;
      if (candidate == null) continue;
      // Ready work already in the queue is handled when a worker becomes free.
      if (!candidate.isAfter(_clock()) && _queue.containsKey(key)) continue;
      if (next == null || candidate.isBefore(next)) next = candidate;
    }
    if (next == null) return;
    final wait = next.difference(_clock());
    _retry = Timer(wait.isNegative ? Duration.zero : wait, () {
      for (final entry in _library.entries) {
        if (_active.contains(entry.key)) continue;
        final picture = _cache[entry.key];
        final deadline = _retryAfter[entry.key] ?? picture?.retryAfter;
        if ((picture == null || picture.needsLookup) &&
            deadline != null &&
            !deadline.isAfter(_clock())) {
          _retryAfter.remove(entry.key);
          _queue[entry.key] = entry.value;
        }
      }
      unawaited(_run());
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    _queue.clear();
    lookup?.close();
    unawaited(_changes.close());
  }
}
