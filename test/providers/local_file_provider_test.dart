import 'package:flutter_test/flutter_test.dart';
import 'package:studio/providers/local_file_provider.dart';
import 'package:studio/providers/playable_resolver.dart';

void main() {
  test('local provider turns a file path into a file URI', () async {
    final uri = await const LocalFileProvider().resolve(
      const TrackLocator(
        source: TrackLocator.local,
        locator: r'C:\music\a.flac',
      ),
    );
    expect(uri.scheme, 'file');
    expect(uri.toFilePath(), r'C:\music\a.flac');
  });

  test('local provider rejects a non-local source', () async {
    expect(
      () => const LocalFileProvider().resolve(
        const TrackLocator(source: 'spotify', locator: 'abc'),
      ),
      throwsArgumentError,
    );
  });
}
