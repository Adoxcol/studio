import 'package:velopack_flutter/velopack_flutter.dart' as velopack;

const studioReleaseFeed =
    'https://github.com/Adoxcol/studio/releases/latest/download/';

typedef AvailableUpdate = ({String version, String? notes});

/// The native updater, behind a seam so the service logic is testable.
abstract class UpdateBackend {
  Future<void> initialize();

  /// Fetches the release feed; null when already up to date.
  Future<AvailableUpdate?> latest();

  /// Downloads the latest release. Velopack reuses a package already on disk.
  Future<void> download();

  Future<void> restartAndApply();
}

class VelopackUpdateBackend implements UpdateBackend {
  @override
  Future<void> initialize() =>
      velopack.initializeVelopack(url: studioReleaseFeed);

  @override
  Future<AvailableUpdate?> latest() async {
    final info = await velopack.getLatestUpdateInfo();
    if (info == null) return null;
    return (
      version: info.targetFullRelease.version,
      notes: info.targetFullRelease.notesMarkdown,
    );
  }

  @override
  Future<void> download() async {
    // velopack_flutter 0.3.2 forwards progress only after the download
    // finishes, so the stream is awaited for completion, not progress.
    await velopack.checkAndDownloadUpdatesWithProgress().drain<void>();
  }

  @override
  Future<void> restartAndApply() => velopack.updateAndRestart();
}
