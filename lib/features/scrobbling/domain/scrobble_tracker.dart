import 'package:studio/features/scrobbling/domain/scrobble_track.dart';
import 'package:studio/state/playback_provider.dart';

sealed class ScrobbleEvent {
  const ScrobbleEvent(this.track);
  final ScrobbleTrack track;
}

/// A new listen started playing.
class NowPlayingEvent extends ScrobbleEvent {
  const NowPlayingEvent(super.track);
}

/// The current listen passed the scrobble threshold.
class ScrobbleReadyEvent extends ScrobbleEvent {
  const ScrobbleReadyEvent(super.track);
}

/// Turns playback snapshots into now-playing and scrobble events.
///
/// Follows the Last.fm rules that ListenBrainz also recommends: a track
/// counts once it is longer than 30 seconds and has been listened to for
/// half its length or four minutes, whichever comes first. Only time
/// actually played counts, so seeking forward does not earn a scrobble.
class ScrobbleTracker {
  ScrobbleTracker({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const minimumLength = Duration(seconds: 30);
  static const maximumThreshold = Duration(minutes: 4);

  /// Position jumps larger than this are seeks, not listening.
  static const _maxStep = Duration(seconds: 5);

  final DateTime Function() _now;
  _Listen? _current;

  List<ScrobbleEvent> observe(PlaybackUiState playback) {
    final artist = playback.artist?.trim() ?? '';
    final title = playback.title.trim();
    if (playback.trackId == null || artist.isEmpty || title.isEmpty) {
      _current = null;
      return const [];
    }
    final key = (playback.trackId, playback.locator);
    var listen = _current;
    if (listen == null || listen.key != key || _restarted(listen, playback)) {
      listen = _Listen(
        key: key,
        startedAt: _now().toUtc().subtract(playback.position),
        lastPosition: playback.position,
      );
      _current = listen;
    } else if (playback.playing) {
      final step = playback.position - listen.lastPosition;
      if (step > Duration.zero && step <= _maxStep) listen.listened += step;
    }
    listen.lastPosition = playback.position;

    final track = ScrobbleTrack(
      artist: artist,
      title: title,
      album: _blankToNull(playback.album),
      duration: playback.duration,
      startedAt: listen.startedAt,
    );
    final events = <ScrobbleEvent>[];
    if (playback.playing && !listen.announced) {
      listen.announced = true;
      events.add(NowPlayingEvent(track));
    }
    if (!listen.scrobbled && _earned(listen, playback.duration)) {
      listen.scrobbled = true;
      events.add(ScrobbleReadyEvent(track));
    }
    return events;
  }

  /// Repeat-one replays the same track id: a jump back to the start after a
  /// substantial listen begins a fresh listen.
  bool _restarted(_Listen listen, PlaybackUiState playback) {
    return playback.position < const Duration(seconds: 2) &&
        listen.lastPosition - playback.position > const Duration(seconds: 10) &&
        (listen.scrobbled || listen.listened > minimumLength);
  }

  static bool _earned(_Listen listen, Duration duration) {
    if (duration <= minimumLength) return false;
    final half = duration ~/ 2;
    final threshold = half < maximumThreshold ? half : maximumThreshold;
    return listen.listened >= threshold;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _Listen {
  _Listen({
    required this.key,
    required this.startedAt,
    required this.lastPosition,
  });

  final (int?, String?) key;
  final DateTime startedAt;
  Duration lastPosition;
  Duration listened = Duration.zero;
  bool announced = false;
  bool scrobbled = false;
}
