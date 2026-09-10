import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';
import 'package:studio/features/artist_artwork/domain/artist_picture.dart';

/// One paced metadata lane per host, plus a bounded pool for image transfers.
/// Cooldowns reject queued work immediately so callers can try another source.
class ArtistRequestScheduler {
  ArtistRequestScheduler({
    this.metadataSpacing = const Duration(milliseconds: 1100),
    this.audioDbSpacing = const Duration(milliseconds: 2100),
    this.maxImageDownloads = 3,
    this.log = const ArtistPictureLog(),
    DateTime Function()? clock,
  }) : assert(maxImageDownloads > 0),
       _clock = clock ?? DateTime.now;

  final Duration metadataSpacing;
  final Duration audioDbSpacing;
  final int maxImageDownloads;
  final ArtistPictureLog log;
  final DateTime Function() _clock;
  final _lanes = <String, _Lane>{};
  final _cooldowns = <String, ArtistServiceException>{};
  final _failures = <String, int>{};
  final _priority = <String>{};
  bool _closed = false;

  void setPriority(String artist, bool value) {
    final key = artistKey(artist);
    value ? _priority.add(key) : _priority.remove(key);
  }

  Future<T> run<T>(
    Uri uri,
    Future<T> Function() operation, {
    required String artist,
    required bool Function() cancelled,
    bool image = false,
  }) {
    if (_closed || cancelled()) {
      return Future.error(StateError('Lookup cancelled'));
    }
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    // AudioDB sometimes serves images on its API hostname: those still belong
    // to the download pool, not its free-tier metadata quota.
    final service = '$host:${image ? 'images' : 'metadata'}';
    final lane = _lanes.putIfAbsent(
      image ? 'images' : service,
      () => _Lane(
        image ? maxImageDownloads : 1,
        image
            ? Duration.zero
            : host == 'theaudiodb.com'
            ? audioDbSpacing
            : metadataSpacing,
      ),
    );
    final result = Completer<T>();
    lane.queue.add(
      _Request(
        artistKey(artist),
        service,
        cancelled,
        (error) => result.completeError(error),
        () async {
          try {
            final value = await operation();
            if (cancelled()) throw StateError('Lookup cancelled');
            // A concurrent success must not clear another request's cooldown.
            if (_cooldowns[service]?.retryAfter?.isAfter(_clock()) != true) {
              _failures.remove(service);
              _cooldowns.remove(service);
            }
            result.complete(value);
          } on Object catch (error, stack) {
            Object failure = error;
            if (!cancelled() && _transient(error)) {
              final count = ((_failures[service] ?? 0) + 1).clamp(1, 6);
              _failures[service] = count;
              final baseSeconds = host == 'theaudiodb.com' && !image ? 60 : 30;
              var deadline = _clock().add(
                Duration(
                  seconds: (baseSeconds * (1 << (count - 1))).clamp(
                    baseSeconds,
                    900,
                  ),
                ),
              );
              for (final candidate in [
                if (error is ArtistServiceException) error.retryAfter,
                _cooldowns[service]?.retryAfter,
              ]) {
                if (candidate != null && candidate.isAfter(deadline)) {
                  deadline = candidate;
                }
              }
              failure = _cooldowns[service] = ArtistServiceException(
                uri.host,
                error is ArtistServiceException ? error.status : 503,
                retryAfter: deadline,
              );
              log(
                '${uri.host} ${image ? 'downloads' : 'metadata'} cooling down until ${deadline.toLocal().toIso8601String()}; other sources remain available.',
                artist: artist,
              );
            } else if (error is ArtistServiceException &&
                _cooldowns[service]?.retryAfter?.isAfter(_clock()) != true) {
              // A definitive HTTP response (such as a missing photo) also
              // establishes recovery after a previous service outage.
              _failures.remove(service);
              _cooldowns.remove(service);
            }
            result.completeError(failure, stack);
          } finally {
            lane.active--;
            _pump(lane);
          }
        },
      ),
    );
    _pump(lane);
    return result.future;
  }

  bool _transient(Object error) {
    if (error is ArtistServiceException) {
      return error.status == 408 || error.status == 429 || error.status >= 500;
    }
    return error is http.ClientException ||
        error is SocketException ||
        error is TimeoutException;
  }

  void _pump(_Lane lane) {
    lane.timer?.cancel();
    lane.timer = null;
    for (final request in lane.queue.toList()) {
      final cooldown = _cooldowns[request.service];
      final Object? error = _closed || request.cancelled()
          ? StateError('Lookup cancelled')
          : cooldown?.retryAfter?.isAfter(_clock()) == true
          ? cooldown
          : null;
      if (error != null) {
        lane.queue.remove(request);
        request.reject(error);
      }
    }
    while (lane.queue.isNotEmpty && lane.active < lane.limit) {
      final wait = lane.lastStart == null
          ? Duration.zero
          : lane.spacing - _clock().difference(lane.lastStart!);
      if (wait > Duration.zero) {
        lane.timer = Timer(wait, () => _pump(lane));
        return;
      }
      var index = lane.queue.indexWhere((r) => _priority.contains(r.artist));
      if (index < 0) index = 0;
      final request = lane.queue.removeAt(index);
      lane.active++;
      lane.lastStart = _clock();
      unawaited(request.start());
    }
  }

  /// Abort queued waits too; active transports are aborted by their owner.
  /// Rate limits/cooldowns survive cancellation and source-setting changes.
  void cancel() {
    for (final lane in _lanes.values) {
      lane.timer?.cancel();
      for (final request in lane.queue) {
        request.reject(StateError('Lookup cancelled'));
      }
      lane.queue.clear();
    }
  }

  void close() {
    _closed = true;
    cancel();
  }
}

class _Lane {
  _Lane(this.limit, this.spacing);
  final int limit;
  final Duration spacing;
  final queue = <_Request>[];
  int active = 0;
  DateTime? lastStart;
  Timer? timer;
}

class _Request {
  _Request(this.artist, this.service, this.cancelled, this.reject, this.start);
  final String artist;
  final String service;
  final bool Function() cancelled;
  final void Function(Object) reject;
  final Future<void> Function() start;
}
