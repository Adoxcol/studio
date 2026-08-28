import 'package:flutter_test/flutter_test.dart';
import 'package:studio/lyrics/lrc.dart';

void main() {
  test('parses synced timestamps and keeps them in order', () {
    const raw = '''
[ar:Aria]
[00:17.12] I feel your breath upon my neck
[00:21.00] A heavy heart
[00:12.00] Opening
''';
    final doc = LrcParser.parse(raw);
    expect(doc.synced, isTrue);
    expect(doc.lines.map((l) => l.text).toList(), [
      'Opening',
      'I feel your breath upon my neck',
      'A heavy heart',
    ]);
    expect(doc.lines.first.start, const Duration(seconds: 12));
    expect(doc.lines[1].start, const Duration(seconds: 17, milliseconds: 120));
  });

  test('applies offset tags and duplicate timestamps', () {
    const raw = '''
[offset:-500]
[00:10.00][00:20.00] Chorus
''';
    final doc = LrcParser.parse(raw);
    expect(doc.lines, hasLength(2));
    expect(doc.lines[0].start, const Duration(milliseconds: 9500));
    expect(doc.lines[1].start, const Duration(milliseconds: 19500));
    expect(doc.lines[0].text, 'Chorus');
  });

  test('plain text becomes unsynced lines', () {
    const raw = 'First line\nSecond line';
    final doc = LrcParser.parse(raw);
    expect(doc.synced, isFalse);
    expect(doc.lines.map((l) => l.text).toList(), [
      'First line',
      'Second line',
    ]);
  });

  test('currentIndex is the last line that has started', () {
    const lines = [
      LrcLine(start: Duration(seconds: 5), text: 'a'),
      LrcLine(start: Duration(seconds: 10), text: 'b'),
    ];
    expect(LyricsDocument.currentIndex(lines, Duration.zero), -1);
    expect(LyricsDocument.currentIndex(lines, const Duration(seconds: 5)), 0);
    expect(LyricsDocument.currentIndex(lines, const Duration(seconds: 12)), 1);
  });
}
