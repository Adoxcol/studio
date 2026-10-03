import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:studio/features/scrobbling/data/scrobble_queue_store.dart';
import 'package:studio/features/scrobbling/domain/scrobble_service.dart';
import 'package:studio/features/scrobbling/domain/scrobble_track.dart';
import 'package:studio/features/scrobbling/domain/scrobble_tracker.dart';

/// Delivers now-playing updates and queued scrobbles to each connected
/// service. Scrobbles are persisted before sending, so an outage or a quit
/// only delays them.
class Scrobbler {
  Scrobbler({
    required ScrobbleQueueStore store,
    this.retryAfter = const Duration(minutes: 1),
    this.maxRetryAfter = const Duration(minutes: 30),
    this.maxQueued = 5000,
    this.onAuthFailure,
  }) : _store = store,
       _queues = store.load();

  final ScrobbleQueueStore _store;
  final Duration retryAfter;
  final Duration maxRetryAfter;

  /// Oldest pending scrobbles are dropped beyond this many per service.
  final int maxQueued;

  /// Called with a service id when that service rejects its credentials.
  final void Function(String serviceId)? onAuthFailure;

  final Map<String, List<ScrobbleTrack>> _queues;
  Map<String, ScrobbleService> _services = {};
  final _retries = <String, Timer>{};
  final _backoff = <String, Duration>{};
  final _inflight = <String, Future<void>>{};
  final _dirty = <String>{};
  var _disposed = false;

  int pending(String serviceId) => _queues[serviceId]?.length ?? 0;

  /// Replaces the set of connected services and sends anything waiting.
  void configure(Iterable<ScrobbleService> services) {
    _services = {for (final service in services) service.id: service};
    for (final id in _retries.keys.toList()) {
      if (!_services.containsKey(id)) _retries.remove(id)?.cancel();
    }
    for (final id in _services.keys) {
      unawaited(flush(id));
    }
  }

  Future<void> handle(ScrobbleEvent event) async {
    if (_disposed) return;
    switch (event) {
      case NowPlayingEvent(:final track):
        await Future.wait([
          for (final service in _services.values) _nowPlaying(service, track),
        ]);
      case ScrobbleReadyEvent(:final track):
        for (final id in _services.keys) {
          final queue = _queues.putIfAbsent(id, () => []);
          queue.add(track);
          if (queue.length > maxQueued) {
            queue.removeRange(0, queue.length - maxQueued);
          }
        }
        if (_services.isEmpty) return;
        _persist();
        await Future.wait([for (final id in _services.keys) flush(id)]);
    }
  }

  Future<void> _nowPlaying(ScrobbleService service, ScrobbleTrack track) async {
    try {
      await service.nowPlaying(track);
    } on ScrobbleException catch (error) {
      if (error.failure == ScrobbleFailure.auth) _authFailed(service.id);
      debugPrint('Now playing update to ${service.id} failed: $error');
    } on Object catch (error) {
      debugPrint('Now playing update to ${service.id} failed: $error');
    }
  }

  /// Sends queued scrobbles for [serviceId] until empty or a failure.
  /// Calls during a running flush join it, and it re-checks the queue so
  /// scrobbles added meanwhile are not missed.
  Future<void> flush(String serviceId) {
    if (_disposed) return Future.value();
    _dirty.add(serviceId);
    return _inflight[serviceId] ??= _flushLoop(serviceId);
  }

  Future<void> _flushLoop(String serviceId) async {
    try {
      while (_dirty.remove(serviceId)) {
        await _drain(serviceId);
      }
    } finally {
      _inflight.remove(serviceId);
    }
  }

  Future<void> _drain(String serviceId) async {
    while (true) {
      final service = _services[serviceId];
      final queue = _queues[serviceId];
      if (service == null || queue == null || queue.isEmpty) return;
      final batch = queue.take(service.maxBatch).toList();
      try {
        await service.submit(batch);
      } on ScrobbleException catch (error) {
        debugPrint('Scrobbling to $serviceId failed: $error');
        switch (error.failure) {
          case ScrobbleFailure.retry:
            _scheduleRetry(serviceId);
            return;
          case ScrobbleFailure.auth:
            _authFailed(serviceId);
            return;
          case ScrobbleFailure.rejected:
            break;
        }
      } on Object catch (error) {
        debugPrint('Scrobbling to $serviceId failed: $error');
        _scheduleRetry(serviceId);
        return;
      }
      _backoff.remove(serviceId);
      queue.removeRange(0, batch.length);
      _persist();
    }
  }

  void _scheduleRetry(String serviceId) {
    if (_disposed || _retries.containsKey(serviceId)) return;
    final wait = _backoff[serviceId] ?? retryAfter;
    final next = wait * 2;
    _backoff[serviceId] = next > maxRetryAfter ? maxRetryAfter : next;
    _retries[serviceId] = Timer(wait, () {
      _retries.remove(serviceId);
      unawaited(flush(serviceId));
    });
  }

  void _authFailed(String serviceId) {
    _services.remove(serviceId);
    _retries.remove(serviceId)?.cancel();
    onAuthFailure?.call(serviceId);
  }

  void _persist() {
    try {
      _store.save(_queues);
    } on Object catch (error) {
      debugPrint('Could not save pending scrobbles: $error');
    }
  }

  void dispose() {
    _disposed = true;
    for (final timer in _retries.values) {
      timer.cancel();
    }
    _retries.clear();
  }
}
