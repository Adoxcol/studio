/// Scores how well [query] matches [text]; null means no match.
///
/// Every whitespace-separated word of the query must match. A word scores
/// highest as a prefix of the text, then at the start of a word, then as a
/// plain substring. With [subsequence], a word may also match letters in
/// order with gaps ("bnw" finds "Bon Iver"-style abbreviations), scored lower.
double? fuzzyScore(String query, String text, {bool subsequence = true}) {
  final words = foldForSearch(query).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return 0;
  final haystack = foldForSearch(text);
  var total = 0.0;
  for (final word in words) {
    final score = _wordScore(word, haystack, subsequence);
    if (score == null) return null;
    total += score;
  }
  // Prefer tighter matches: "Blue" over "Blue Moon Rising Remastered".
  return total - haystack.length * 0.01;
}

double? _wordScore(String word, String text, bool subsequence) {
  if (text.startsWith(word)) return 100;
  var index = text.indexOf(word);
  while (index > 0) {
    if (_isBoundary(text.codeUnitAt(index - 1))) return 70;
    index = text.indexOf(word, index + 1);
  }
  if (text.contains(word)) return 40;
  if (!subsequence) return null;
  var position = 0;
  var gaps = 0;
  var starts = 0;
  for (final unit in word.codeUnits) {
    final found = text.indexOf(String.fromCharCode(unit), position);
    if (found < 0) return null;
    if (found > position) gaps += found - position;
    if (found == 0 || _isBoundary(text.codeUnitAt(found - 1))) starts++;
    position = found + 1;
  }
  final score = 20 + starts * 4 - gaps * 0.5;
  return score < 1 ? 1 : score;
}

bool _isBoundary(int unit) =>
    unit == 0x20 || // space
    unit == 0x2D || // -
    unit == 0x5F || // _
    unit == 0x2F || // /
    unit == 0x28 || // (
    unit == 0x26 || // &
    unit == 0x2E; //   .

const _folds = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'æ': 'ae',
  'ç': 'c',
  'č': 'c',
  'ć': 'c',
  'ď': 'd',
  'ð': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ě': 'e',
  'ę': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ł': 'l',
  'ľ': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ő': 'o',
  'œ': 'oe',
  'ř': 'r',
  'ß': 'ss',
  'š': 's',
  'ś': 's',
  'ş': 's',
  'ť': 't',
  'þ': 'th',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
};

/// Lowercases and strips common Latin diacritics, so "bjork" finds "Björk".
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  var plain = true;
  for (final unit in lower.codeUnits) {
    if (unit > 0x7F) {
      plain = false;
      break;
    }
  }
  if (plain) return lower;
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }
  return buffer.toString();
}
