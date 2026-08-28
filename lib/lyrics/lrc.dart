/// One line of a parsed lyrics document.
class LrcLine {
  const LrcLine({required this.start, required this.text});

  final Duration start;
  final String text;
}

class LyricsDocument {
  const LyricsDocument({
    this.lines = const [],
    this.synced = false,
    this.instrumental = false,
    this.missing = false,
  });

  final List<LrcLine> lines;
  final bool synced;
  final bool instrumental;
  final bool missing;

  static const empty = LyricsDocument();
  static const none = LyricsDocument(missing: true);
  static const instrumentalTrack = LyricsDocument(instrumental: true);

  bool get hasLines => lines.isNotEmpty;

  /// Index of the last line whose [LrcLine.start] is at or before [position].
  /// Returns `-1` when no line has started yet.
  static int currentIndex(List<LrcLine> lines, Duration position) {
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].start <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }
}

/// Parses Enhanced LRC and plain-text lyrics.
abstract final class LrcParser {
  static final _timestamp = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  static final _offset = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false);
  static final _idTag = RegExp(r'^\[[a-zA-Z]+:.*\]\s*$');

  static LyricsDocument parse(String raw, {bool treatUntimedAsPlain = true}) {
    final trimmed = raw.replaceAll('\r\n', '\n').trim();
    if (trimmed.isEmpty) return LyricsDocument.empty;

    var offsetMs = 0;
    final timed = <LrcLine>[];
    final plain = <LrcLine>[];

    for (final original in trimmed.split('\n')) {
      final line = original.trim();
      if (line.isEmpty) continue;
      final offsetMatch = _offset.firstMatch(line);
      if (offsetMatch != null) {
        offsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
        continue;
      }
      final stamps = _timestamp.allMatches(line).toList();
      if (stamps.isEmpty) {
        if (_idTag.hasMatch(line)) continue;
        plain.add(LrcLine(start: Duration.zero, text: line));
        continue;
      }
      final text = line.substring(stamps.last.end).trim();
      if (text.isEmpty) continue;
      for (final stamp in stamps) {
        timed.add(
          LrcLine(
            start: _timestampDuration(stamp, offsetMs: offsetMs),
            text: text,
          ),
        );
      }
    }

    if (timed.isNotEmpty) {
      timed.sort((a, b) => a.start.compareTo(b.start));
      return LyricsDocument(lines: timed, synced: true);
    }
    if (treatUntimedAsPlain && plain.isNotEmpty) {
      return LyricsDocument(lines: plain, synced: false);
    }
    return LyricsDocument.empty;
  }

  static Duration _timestampDuration(
    RegExpMatch match, {
    required int offsetMs,
  }) {
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    final ms = _fractionToMs(match.group(3));
    final total =
        Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: ms,
        ).inMilliseconds +
        offsetMs;
    return Duration(milliseconds: total < 0 ? 0 : total);
  }

  static int _fractionToMs(String? fraction) {
    if (fraction == null || fraction.isEmpty) return 0;
    if (fraction.length == 1) return int.parse(fraction) * 100;
    if (fraction.length == 2) return int.parse(fraction) * 10;
    return int.parse(fraction.substring(0, 3));
  }
}
