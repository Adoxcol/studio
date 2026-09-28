import 'dart:io';

/// Writes the CHANGELOG.md section for a release as GitHub Release notes.
///
/// Usage: `dart tool/release_notes.dart <version> <output file>`
///
/// Self-contained (no package imports) so it runs with a bare Dart SDK.
/// Fails when the version has no section, so a tag without release notes
/// stops before anything is built.
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: dart tool/release_notes.dart <version> <output>');
    exitCode = 64;
    return;
  }
  final version = args[0].startsWith('v') ? args[0].substring(1) : args[0];
  final notes = releaseNotesFor(
    File('CHANGELOG.md').readAsStringSync(),
    version,
  );
  if (notes == null) {
    stderr.writeln('CHANGELOG.md has no "## [$version]" section with notes.');
    exitCode = 1;
    return;
  }
  File(args[1]).writeAsStringSync(notes);
}

/// The body of the `## [version]` section of [changelog], or null when the
/// section is missing or empty.
///
/// Wrapped list items are joined into one line each: GitHub shows every line
/// break in a release description, so the changelog's 80-column wrapping
/// would otherwise break sentences mid-way.
String? releaseNotesFor(String changelog, String version) {
  final lines = changelog.replaceAll('\r\n', '\n').split('\n');
  final heading = RegExp(r'^## \[' + RegExp.escape(version) + r'\]');
  final start = lines.indexWhere(heading.hasMatch);
  if (start < 0) return null;
  final body = <String>[];
  for (final line in lines.skip(start + 1)) {
    if (line.startsWith('## ')) break;
    final continuation = RegExp(r'^\s{2,}\S').hasMatch(line);
    if (continuation && body.isNotEmpty && body.last.trim().isNotEmpty) {
      body[body.length - 1] = '${body.last} ${line.trim()}';
    } else {
      body.add(line);
    }
  }
  final text = body.join('\n').trim();
  return text.isEmpty ? null : '$text\n';
}
