import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:velopack_flutter/velopack_flutter.dart' as velopack;

const studioReleaseFeed =
    'https://github.com/Adoxcol/studio/releases/latest/download/';

@immutable
class UpdateState {
  const UpdateState({
    this.ready = false,
    this.checking = false,
    this.downloading = false,
    this.version,
    this.notes,
    this.error,
    this.initialized = false,
  });

  final bool ready;
  final bool checking;
  final bool downloading;
  final String? version;
  final String? notes;
  final Object? error;
  final bool initialized;

  UpdateState copyWith({
    bool? ready,
    bool? checking,
    bool? downloading,
    String? version,
    String? notes,
    Object? error,
    bool? initialized,
    bool clearError = false,
  }) {
    return UpdateState(
      ready: ready ?? this.ready,
      checking: checking ?? this.checking,
      downloading: downloading ?? this.downloading,
      version: version ?? this.version,
      notes: notes ?? this.notes,
      error: clearError ? null : error ?? this.error,
      initialized: initialized ?? this.initialized,
    );
  }
}

class UpdateService extends ChangeNotifier {
  UpdateState _state = const UpdateState();
  StreamSubscription<int>? _progress;

  UpdateState get state => _state;

  Future<void> initialize() async {
    if (_state.initialized) return;
    try {
      await velopack.initializeVelopack(url: studioReleaseFeed);
      _state = _state.copyWith(initialized: true, clearError: true);
      notifyListeners();
      unawaited(check(silent: true));
    } catch (error) {
      _log('initialization failed: $error');
      _state = _state.copyWith(initialized: true, error: error);
      notifyListeners();
    }
  }

  Future<void> check({bool silent = false}) async {
    if (!_state.initialized || _state.checking || _state.downloading) return;
    _state = _state.copyWith(checking: true, clearError: true);
    notifyListeners();
    _log('update check started');
    try {
      final info = await velopack.getLatestUpdateInfo();
      if (info == null) {
        _log('no update available');
        return;
      }
      _log('update available: ${info.targetFullRelease.version}');
      _state = _state.copyWith(
        version: info.targetFullRelease.version,
        notes: info.targetFullRelease.notesMarkdown,
      );
      notifyListeners();
      await _download();
    } catch (error) {
      _log('update check failed: $error');
      if (!silent) {
        _state = _state.copyWith(error: error);
        notifyListeners();
      }
    } finally {
      _state = _state.copyWith(checking: false);
      notifyListeners();
    }
  }

  Future<void> _download() async {
    _state = _state.copyWith(downloading: true);
    notifyListeners();
    _log('update download started');
    try {
      await _progress?.cancel();
      _progress = velopack.checkAndDownloadUpdatesWithProgress().listen(
        (progress) => _log('update download: $progress%'),
      );
      await _progress?.asFuture<void>();
      _state = _state.copyWith(ready: true, downloading: false);
      _log('update ready');
      notifyListeners();
    } finally {
      await _progress?.cancel();
      _progress = null;
      _state = _state.copyWith(downloading: false);
    }
  }

  Future<void> restartAndUpdate() async {
    if (!_state.ready) return;
    _log('restart requested');
    await velopack.updateAndRestart();
  }

  void clearReady() {
    _state = _state.copyWith(ready: false, version: null, notes: null);
    notifyListeners();
  }

  void _log(String message) => debugPrint('Studio updater: $message');

  @override
  void dispose() {
    unawaited(_progress?.cancel());
    super.dispose();
  }
}
