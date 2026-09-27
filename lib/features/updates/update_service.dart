import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:studio/features/updates/update_backend.dart';

export 'package:studio/features/updates/update_backend.dart'
    show studioReleaseFeed;

enum UpdatePhase { idle, checking, downloading, ready }

@immutable
class UpdateState {
  const UpdateState({
    this.phase = UpdatePhase.idle,
    this.version,
    this.notes,
    this.error,
    this.timedOut = false,
    this.lastChecked,
    this.upToDate = false,
    this.initialized = false,
  });

  final UpdatePhase phase;
  final String? version;
  final String? notes;
  final Object? error;

  /// The last check gave up waiting for the release server.
  final bool timedOut;
  final DateTime? lastChecked;

  /// The last completed check found nothing newer.
  final bool upToDate;
  final bool initialized;

  bool get checking => phase == UpdatePhase.checking;
  bool get downloading => phase == UpdatePhase.downloading;
  bool get ready => phase == UpdatePhase.ready;
  bool get busy => checking || downloading;

  UpdateState copyWith({
    UpdatePhase? phase,
    String? version,
    String? notes,
    Object? error,
    bool? timedOut,
    DateTime? lastChecked,
    bool? upToDate,
    bool? initialized,
    bool clearError = false,
    bool clearRelease = false,
  }) {
    return UpdateState(
      phase: phase ?? this.phase,
      version: clearRelease ? null : version ?? this.version,
      notes: clearRelease ? null : notes ?? this.notes,
      error: clearError ? null : error ?? this.error,
      timedOut: clearError ? false : timedOut ?? this.timedOut,
      lastChecked: lastChecked ?? this.lastChecked,
      upToDate: upToDate ?? this.upToDate,
      initialized: initialized ?? this.initialized,
    );
  }
}

class UpdateService extends ChangeNotifier {
  UpdateService({
    UpdateBackend? backend,
    this.checkTimeout = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _backend = backend ?? VelopackUpdateBackend(),
       _now = now ?? DateTime.now;

  final UpdateBackend _backend;

  /// How long to wait for the release feed. The native request cannot be
  /// cancelled, so a late answer is ignored rather than stopped.
  final Duration checkTimeout;
  final DateTime Function() _now;

  UpdateState _state = const UpdateState();
  var _attempt = 0;
  var _disposed = false;

  UpdateState get state => _state;

  void _set(UpdateState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_state.initialized) return;
    try {
      await _backend.initialize();
      _set(_state.copyWith(initialized: true, clearError: true));
      unawaited(check(silent: true));
    } catch (error) {
      _log('initialization failed: $error');
      _set(_state.copyWith(initialized: true, error: error));
    }
  }

  /// Checks the feed and, if a newer release exists, downloads it.
  ///
  /// "Checking" covers only the feed request, bounded by [checkTimeout];
  /// the download is reported separately so a large package does not look
  /// like a stuck check.
  Future<void> check({bool silent = false}) async {
    if (!_state.initialized || _state.busy || _state.ready) return;
    final attempt = ++_attempt;
    _set(
      _state.copyWith(
        phase: UpdatePhase.checking,
        upToDate: false,
        clearError: true,
      ),
    );
    _log('update check started');
    final AvailableUpdate? update;
    try {
      update = await _backend.latest().timeout(checkTimeout);
    } on TimeoutException {
      if (attempt != _attempt) return;
      _log('update check timed out after ${checkTimeout.inSeconds}s');
      _set(
        _state.copyWith(
          phase: UpdatePhase.idle,
          error: silent ? null : 'timeout',
          timedOut: !silent,
        ),
      );
      return;
    } catch (error) {
      if (attempt != _attempt) return;
      _log('update check failed: $error');
      _set(
        _state.copyWith(phase: UpdatePhase.idle, error: silent ? null : error),
      );
      return;
    }
    if (attempt != _attempt) return;
    if (update == null) {
      _log('no update available');
      _set(
        _state.copyWith(
          phase: UpdatePhase.idle,
          upToDate: true,
          lastChecked: _now(),
        ),
      );
      return;
    }
    _log('update available: ${update.version}');
    _set(
      _state.copyWith(
        phase: UpdatePhase.downloading,
        version: update.version,
        notes: update.notes,
        lastChecked: _now(),
      ),
    );
    try {
      await _backend.download();
      if (attempt != _attempt) return;
      _log('update ready');
      _set(_state.copyWith(phase: UpdatePhase.ready));
    } catch (error) {
      if (attempt != _attempt) return;
      _log('update download failed: $error');
      _set(
        _state.copyWith(phase: UpdatePhase.idle, error: silent ? null : error),
      );
    }
  }

  Future<void> restartAndUpdate() async {
    if (!_state.ready) return;
    _log('restart requested');
    await _backend.restartAndApply();
  }

  void clearReady() {
    _set(_state.copyWith(phase: UpdatePhase.idle, clearRelease: true));
  }

  void _log(String message) => debugPrint('Studio updater: $message');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
