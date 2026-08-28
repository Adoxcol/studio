import 'package:flutter_test/flutter_test.dart';
import 'package:studio/providers/local_file_provider.dart';
import 'package:studio/providers/playable_resolver.dart';

void main() {
  const provider = LocalFileProvider();

  test('local provider turns a Windows path into a file URI', () async {
    final uri = await provider.resolve(
      const TrackLocator(
        source: TrackLocator.local,
        locator: r'C:\music\a.flac',
      ),
    );
    expect(uri.scheme, 'file');
    expect(uri.toFilePath(windows: true), r'C:\music\a.flac');
  });

  test('local provider turns a POSIX path into a file URI', () async {
    final uri = await provider.resolve(
      const TrackLocator(source: TrackLocator.local, locator: '/music/a.flac'),
    );
    expect(uri.scheme, 'file');
    expect(uri.path, '/music/a.flac');
  });

  test('local provider rejects a non-local source', () async {
    expect(
      () => provider.resolve(
        const TrackLocator(source: 'spotify', locator: 'abc'),
      ),
      throwsArgumentError,
    );
  });
}
