import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/artist_artwork/data/artist_picture_log.dart';

void main() {
  test(
    'artist logs have a recognizable prefix and cannot inject console lines',
    () {
      final lines = <String>[];
      final log = ArtistPictureLog(lines.add);
      log('HTTP 200\nDownloaded', artist: 'Aria\r\nSolvang');
      expect(
        lines.single,
        '[Artist pictures] ["Aria  Solvang"] HTTP 200 Downloaded',
      );
      log('Fetching enabled.');
      expect(lines.last, '[Artist pictures] Fetching enabled.');
    },
  );

  test('diagnostics are bounded and never propagate console failures', () {
    final lines = <String>[];
    ArtistPictureLog(lines.add)('x' * 2000, artist: 'a' * 2000);
    expect(lines.single.length, lessThan(1250));
    expect(
      () => ArtistPictureLog((_) => throw StateError('closed console'))(
        'Downloaded',
      ),
      returnsNormally,
    );
    expect(() => const ArtistPictureLog()('Downloaded'), returnsNormally);
  });
}
