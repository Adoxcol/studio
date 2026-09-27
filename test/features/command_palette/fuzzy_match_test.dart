import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/command_palette/domain/fuzzy_match.dart';
import 'package:studio/features/command_palette/domain/palette_command.dart';

PaletteCommand cmd(
  String title, {
  PaletteKind kind = PaletteKind.artist,
  String? subtitle,
  List<String> keywords = const [],
}) => PaletteCommand(
  id: '$kind:$title',
  kind: kind,
  title: title,
  subtitle: subtitle,
  keywords: keywords,
  run: () {},
);

void main() {
  group('fuzzyScore', () {
    test('prefix beats word start beats substring beats subsequence', () {
      final prefix = fuzzyScore('blue', 'Blue Moon')!;
      final wordStart = fuzzyScore('moon', 'Blue Moon')!;
      final substring = fuzzyScore('oon', 'Blue Moon')!;
      final subsequence = fuzzyScore('bmn', 'Blue Moon')!;
      expect(prefix, greaterThan(wordStart));
      expect(wordStart, greaterThan(substring));
      expect(substring, greaterThan(subsequence));
    });

    test('every word must match, in any order', () {
      expect(fuzzyScore('moon blue', 'Blue Moon'), isNotNull);
      expect(fuzzyScore('blue sun', 'Blue Moon'), isNull);
      expect(fuzzyScore('  ', 'anything'), 0);
    });

    test('subsequence matching can be switched off', () {
      expect(fuzzyScore('bmn', 'Blue Moon', subsequence: false), isNull);
      expect(fuzzyScore('moo', 'Blue Moon', subsequence: false), isNotNull);
    });

    test('ignores accents on either side', () {
      expect(fuzzyScore('bjork', 'Björk'), fuzzyScore('björk', 'Björk'));
      expect(fuzzyScore('sigur ros', 'Sigur Rós'), isNotNull);
      expect(fuzzyScore('Beyoncé', 'beyonce'), isNotNull);
      expect(foldForSearch('Straße Œuvre'), 'strasse oeuvre');
    });

    test('shorter texts win ties', () {
      expect(
        fuzzyScore('blue', 'Blue')!,
        greaterThan(fuzzyScore('blue', 'Blue Moon Rising (Remastered)')!),
      );
    });
  });

  group('rankCommands', () {
    final commands = [
      cmd('Library', kind: PaletteKind.screen),
      cmd('Settings', kind: PaletteKind.screen, keywords: ['preferences']),
      cmd('Play / Pause', kind: PaletteKind.action),
      cmd('Björk'),
      cmd('Homogenic', kind: PaletteKind.album, subtitle: 'Björk'),
      cmd('Jóga', kind: PaletteKind.track, subtitle: 'Björk — Homogenic'),
      cmd('Settle Down', kind: PaletteKind.track),
    ];

    test('an empty query lists screens and actions only', () {
      expect(rankCommands('', commands).map((c) => c.title), [
        'Library',
        'Settings',
        'Play / Pause',
      ]);
    });

    test('ranks by score, then by kind', () {
      final titles = rankCommands('set', commands).map((c) => c.title);
      expect(titles.first, 'Settings');
      expect(titles, contains('Settle Down'));
    });

    test('finds commands by keyword and by subtitle', () {
      expect(rankCommands('prefer', commands).single.title, 'Settings');
      expect(
        rankCommands('björk homo', commands).map((c) => c.title),
        contains('Homogenic'),
      );
    });

    test('tracks need substring matches', () {
      expect(
        rankCommands('stld', commands).map((c) => c.title),
        isNot(contains('Settle Down')),
      );
    });

    test('respects the limit', () {
      final many = [for (var i = 0; i < 80; i++) cmd('Artist $i')];
      expect(rankCommands('artist', many, limit: 10), hasLength(10));
    });
  });
}
