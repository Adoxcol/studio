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
  return formatDuration(Duration(milliseconds: durationMs));
}
