import 'package:studio/features/command_palette/domain/fuzzy_match.dart';

/// What a result opens or does; also its order when scores tie.
enum PaletteKind {
  screen('Go to'),
  action('Action'),
  artist('Artist'),
  album('Album'),
  playlist('Playlist'),
  track('Track');

  const PaletteKind(this.label);
  final String label;
}

class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.kind,
    required this.title,
    required this.run,
    this.subtitle,
    this.keywords = const [],
    this.shortcut,
  });

  final String id;
  final PaletteKind kind;
  final String title;
  final String? subtitle;

  /// Extra words that find this command, e.g. "preferences" for Settings.
  final List<String> keywords;

  /// Shown on the right, e.g. "Ctrl+Shift+M".
  final String? shortcut;
  final void Function() run;
}

/// Best matches for [query]. An empty query lists screens and actions.
List<PaletteCommand> rankCommands(
  String query,
  Iterable<PaletteCommand> commands, {
  int limit = 50,
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return [
      for (final command in commands)
        if (command.kind == PaletteKind.screen ||
            command.kind == PaletteKind.action)
          command,
    ].take(limit).toList();
  }
  final scored = <(PaletteCommand, double)>[];
  for (final command in commands) {
    // Tracks are numerous; substring matching keeps typing responsive.
    final loose = command.kind != PaletteKind.track;
    double? best = fuzzyScore(trimmed, command.title, subsequence: loose);
    final extra = [
      if (command.subtitle case final subtitle?) '${command.title} $subtitle',
      ...command.keywords,
    ];
    for (final text in extra) {
      final score = fuzzyScore(trimmed, text, subsequence: loose);
      if (score != null && (best == null || score - 5 > best)) {
        best = score - 5;
      }
    }
    if (best != null) scored.add((command, best));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    return a.$1.kind.index.compareTo(b.$1.kind.index);
  });
  return [for (final (command, _) in scored.take(limit)) command];
}
