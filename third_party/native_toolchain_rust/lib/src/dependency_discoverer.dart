import 'dart:io';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

@internal
interface class DependencyDiscoverer {
  const DependencyDiscoverer(this.logger);

  final Logger logger;

  /// Finds all the source dependencies listed in the specified Cargo dep-info
  /// file.
  ///
  /// The dep-info file itself is intentionally **not** included in the result:
  /// Cargo refreshes its mtime on every invocation (even no-op rebuilds), which
  /// causes Flutter's build graph to detect mid-build modifications and emit
  /// `File modified during build. Build must be rerun.` warnings. The source
  /// files parsed out of the dep-info already provide complete change-detection
  /// coverage for incremental rebuilds.
  Iterable<Uri> discover(String dependencyFilePath) {
    logger.fine('Discovering dependencies in $dependencyFilePath');
    final contents = File(dependencyFilePath).readAsLinesSync().join(' ');
    final separator = contents.indexOf(': ');
    if (separator == -1) return const [];

    return contents
        .substring(separator + 2)
        .trim()
        .split(RegExp(r'(?<!\\) '))
        .where((dependency) => dependency.isNotEmpty)
        .map((dependency) => dependency.replaceAll(r'\ ', ' '))
        .map(path.toUri);
  }
}
