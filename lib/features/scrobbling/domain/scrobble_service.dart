import 'package:studio/features/scrobbling/domain/scrobble_track.dart';

/// How a submission failed, which decides what happens to the queue.
enum ScrobbleFailure {
  /// Network trouble, rate limit or server error: keep the batch and retry.
  retry,

  /// Credentials were rejected: keep the queue and stop until reconnected.
  auth,

  /// The service refused this batch outright: drop it and continue.
  rejected,
}

class ScrobbleException implements Exception {
  const ScrobbleException(this.failure, this.message);

  final ScrobbleFailure failure;
  final String message;

  @override
  String toString() => 'ScrobbleException(${failure.name}): $message';
}

/// A scrobbling backend such as Last.fm or ListenBrainz.
abstract class ScrobbleService {
  /// Stable id used to key this service's pending queue.
  String get id;

  /// Largest batch [submit] accepts.
  int get maxBatch;

  Future<void> nowPlaying(ScrobbleTrack track);

  /// Throws [ScrobbleException] when the batch was not accepted.
  Future<void> submit(List<ScrobbleTrack> batch);
}
