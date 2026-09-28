import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_notes.dart';

const _changelog = '''
# Changelog

## [Unreleased]

### Fixed

- Something not released yet.

## [1.2.0] - 2026-10-01

### Added

- A feature with a long description that wraps
  onto a second line.

### Fixed

- A fix.

## [1.1.0] - 2026-09-01

- Older.
''';

void main() {
  test('extracts one version and joins wrapped lines', () {
    expect(
      releaseNotesFor(_changelog, '1.2.0'),
      '### Added\n\n'
      '- A feature with a long description that wraps onto a second line.\n\n'
      '### Fixed\n\n'
      '- A fix.\n',
    );
  });

  test('missing or empty sections return null', () {
    expect(releaseNotesFor(_changelog, '9.9.9'), isNull);
    expect(releaseNotesFor('## [2.0.0]\n\n## [1.0.0]\n- x\n', '2.0.0'), isNull);
  });

  test('versions are matched literally', () {
    // "1.2.0" must not match a "1x2x0" heading via regex dots.
    expect(releaseNotesFor('## [1x2x0]\n- nope\n', '1.2.0'), isNull);
  });

  test('every released version in CHANGELOG.md has notes', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final versions = RegExp(
      r'^## \[(\d+\.\d+\.\d+)\]',
      multiLine: true,
    ).allMatches(changelog).map((m) => m[1]!).toList();
    expect(versions, isNotEmpty);
    for (final version in versions) {
      expect(releaseNotesFor(changelog, version), isNotNull, reason: version);
    }
  });
}
