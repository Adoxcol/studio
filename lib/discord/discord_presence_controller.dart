import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:studio/discord/discord_artwork.dart';
import 'package:studio/discord/discord_presence.dart';
import 'package:studio/discord/discord_rpc_client.dart';
import 'package:studio/discord/discord_settings.dart';
import 'package:studio/state/playback_provider.dart';

/// Pushes playback onto Discord and reconnects if the client was not running.
class DiscordPresenceController {
  DiscordPresenceController({
    required DiscordRpcClient client,
    this.retryEvery = const Duration(seconds: 20),
    Duration? debounce,
    DiscordArtworkResolver? artwork,
    DateTime Function()? now,
  }) : _client = client,
       _debounceFor = debounce,
       _artwork = artwork,
       _now = now ?? DateTime.now;

  static const _defaultDebounce = Duration(milliseconds: 300);

  final DiscordRpcClient _client;
  final Duration retryEvery;
  final Duration? _debounceFor;
  final DiscordArtworkResolver? _artwork;
  final DateTime Function() _now;

  /// Hot reload can leave a new field null on an existing instance.
  Duration get _wait => _debounceFor ?? _defaultDebounce;

  var _connected = false;
  DiscordPresenceView? _last;
  Timer? _retry;
  Timer? _debounce;
  Completer<void>? _debounced;
  var _enabled = false;
  PlaybackUiState _latest = const PlaybackUiState();
  DiscordSettings _settings = DiscordSettings.defaults;
  var _flushing = false;
  var _dirty = false;

  @visibleForTesting
  bool get isConnected => _connected;

  @visibleForTesting
  DiscordPresenceView? get lastView => _last;

  Future<void> sync({
    required bool enabled,
    required PlaybackUiState playback,
    DiscordSettings settings = DiscordSettings.defaults,
  }) async {
    _enabled = enabled;
    _latest = playback;
    _settings = settings;
    _debounce?.cancel();
    final previous = _debounced;
    if (previous != null && !previous.isCompleted) {
      previous.complete();
    }
    final wait = _wait;
    if (wait <= Duration.zero) {
      _debounced = null;
      await _flush();
      return;
    }
    final done = Completer<void>();
    _debounced = done;
    _debounce = Timer(wait, () {
      unawaited(
        _flush().then(
          (_) {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stack) {
            if (!done.isCompleted) done.completeError(error, stack);
          },
        ),
      );
    });
    return done.future;
  }

  Future<void> dispose() async {
    _enabled = false;
    _debounce?.cancel();
    _debounce = null;
    _retry?.cancel();
    _retry = null;
    await _flush();
  }

  Future<void> _flush() async {
    _dirty = true;
    if (_flushing) return;
    _flushing = true;
    try {
      while (_dirty) {
        _dirty = false;
        await _apply(enabled: _enabled, playback: _latest);
      }
    } finally {
      _flushing = false;
      if (_dirty) unawaited(_flush());
    }
  }

  Future<void> _apply({
    required bool enabled,
    required PlaybackUiState playback,
  }) async {
    if (!enabled) {
      _retry?.cancel();
      _retry = null;
      await _clear();
      return;
    }
    if (_connected && !_client.isConnected) {
      _connected = false;
      _last = null;
    }
    final cover = _artwork?.cachedUrl(playback.artworkPath);
    final view = discordPresenceFor(
      playback,
      now: _now(),
      largeImage: cover,
      settings: _settings,
    );
    if (view == null) {
      _retry?.cancel();
      _retry = null;
      await _clear();
      return;
    }
    if (_connected && _last != null && _sameActivity(_last!, view)) {
      unawaited(_warmArtwork(playback.artworkPath, cover));
      return;
    }
    try {
      if (!_connected) {
        await _client.connect();
        _connected = true;
      }
      await _client.setActivity(view);
      _last = view;
      _retry?.cancel();
      _retry = null;
    } on Object catch (error) {
      debugPrint('Discord RPC update failed: $error');
      _connected = false;
      _last = null;
      _scheduleRetry();
    }
    unawaited(_warmArtwork(playback.artworkPath, cover));
  }

  Future<void> _warmArtwork(String? path, String? already) async {
    if (already != null || path == null || _artwork == null) return;
    try {
      final url = await _artwork.urlFor(path);
      if (url == null || !_enabled) return;
      await _flush();
    } on Object catch (error) {
      debugPrint('Discord artwork lookup failed: $error');
    }
  }

  Future<void> _clear() async {
    _last = null;
    if (!_connected) return;
    _connected = false;
    try {
      await _client.clear();
    } on Object catch (error) {
      debugPrint('Discord RPC clear failed: $error');
    }
  }

  void _scheduleRetry() {
    if (!_enabled || _retry != null) return;
    _retry = Timer(retryEvery, () {
      _retry = null;
      if (!_enabled) return;
      unawaited(_flush());
    });
  }

  /// Ignore clock drift so a duration tick does not rewrite the pipe.
  static bool _sameActivity(DiscordPresenceView a, DiscordPresenceView b) {
    return a.name == b.name &&
        a.details == b.details &&
        a.state == b.state &&
        a.album == b.album &&
        a.largeImage == b.largeImage &&
        a.playing == b.playing &&
        (a.start != null) == (b.start != null);
  }
}
