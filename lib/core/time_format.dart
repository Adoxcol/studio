final _durationMsCache = <int, String>{};

String formatDuration(Duration duration) {
  final negative = duration.isNegative;
  final abs = duration.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = abs.inSeconds.remainder(60).toString().padLeft(2, '0');
  final body = hours > 0
      ? '$hours:$minutes:$seconds'
      : '${abs.inMinutes}:$seconds';
  return negative ? '-$body' : body;
}

String formatDurationMs(int? durationMs) {
  if (durationMs == null || durationMs < 0) return '';

  final cached = _durationMsCache[durationMs];
  if (cached != null) return cached;

  final result = formatDuration(Duration(milliseconds: durationMs));
  // Cap the cache size just to be safe, though duration Ms are highly reused
  // across same tracks or repeated searches, if it gets too large we can clear it.
  if (_durationMsCache.length > 20000) {
    _durationMsCache.clear();
  }
  _durationMsCache[durationMs] = result;

  return result;
}
