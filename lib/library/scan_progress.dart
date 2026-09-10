class ScanResult {
  const ScanResult({
    this.seen = 0,
    this.written = 0,
    this.skipped = 0,
    this.cancelled = false,
    this.unavailableFolders = 0,
  });

  final int seen;
  final int written;
  final int skipped;
  final bool cancelled;
  final int unavailableFolders;
}

class ScanProgress {
  const ScanProgress({
    this.active = false,
    this.folderLabel = '',
    this.processed = 0,
    this.total = 0,
    this.skipped = 0,
  });

  final bool active;
  final String folderLabel;
  final int processed;
  final int total;
  final int skipped;

  static const idle = ScanProgress();

  String get detail {
    if (total > 0) return '$processed of $total files';
    if (processed > 0) return '$processed files';
    return 'Looking for files…';
  }
}
