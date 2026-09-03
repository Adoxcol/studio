import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/smart_playlists/domain/smart_playlist.dart';
import 'package:studio/library/library_query.dart';
import '../../helpers/tracks.dart';

void main() {
  test(
    'all/any rules handle mixed text and numeric values and missing tags',
    () {
      final tracks = [
        testTrack(id: 1, title: 'A', genre: 'Ambient', year: 2024),
        testTrack(id: 2, title: 'B', genre: 'Jazz', year: 2025),
        testTrack(id: 3, title: 'C', genre: 'Ambient'),
      ];
      const rules = [
        SmartRule(SmartField.genre, SmartOperator.equals, 'ambient'),
        SmartRule(SmartField.year, SmartOperator.atLeast, '2020'),
      ];
      expect(
        SmartPlaylistDefinition(rules: rules).evaluate(tracks).map((t) => t.id),
        [1],
      );
      expect(
        SmartPlaylistDefinition(
          rules: rules,
          matchAll: false,
        ).evaluate(tracks).length,
        3,
      );
      expect(
        const SmartRule(
          SmartField.year,
          SmartOperator.atMost,
          '2030',
        ).matches(tracks.last),
        isFalse,
      );
    },
  );

  test('quality rules, credited artists and sorting round-trip', () {
    final track = testTrack(
      id: 1,
      title: 'B',
      locator: '/music/a.FLAC',
      artist: 'Aria & Sam',
      sampleRateHz: 96000,
      durationMs: 1000,
      fileSizeBytes: 125000,
    );
    final definition = SmartPlaylistDefinition(
      rules: const [
        SmartRule(SmartField.artist, SmartOperator.equals, 'Sam'),
        SmartRule(SmartField.format, SmartOperator.equals, 'flac'),
        SmartRule(SmartField.lossless, SmartOperator.equals, 'true'),
        SmartRule(SmartField.sampleRate, SmartOperator.atLeast, '96000'),
        SmartRule(SmartField.bitrate, SmartOperator.atLeast, '1000'),
      ],
      sort: LibrarySort.title,
      order: LibraryOrder.descending,
    );
    final decoded = SmartPlaylistDefinition.decode(definition.encode());
    expect(
      decoded
          .evaluate([track, track.copyWith(id: 2, title: 'Z')])
          .map((t) => t.title),
      ['Z', 'B'],
    );
  });

  test('current search and filters retain AND semantics', () {
    final definition = SmartPlaylistDefinition.fromFilters(
      filters: const LibraryTrackFilters(
        losslessOnly: true,
        year: 2024,
        minimumSampleRateHz: 48000,
      ),
      query: 'night',
      artist: 'Sam',
      album: 'Blue',
      sort: LibrarySort.album,
    );
    final track = testTrack(
      title: 'Night',
      artist: 'Sam',
      album: 'Blue',
      year: 2024,
      sampleRateHz: 96000,
      locator: '/song.flac',
    );
    expect(definition.evaluate([track]), hasLength(1));
    expect(definition.evaluate([track.copyWith(title: 'Day')]), isEmpty);
    expect(definition.sort, LibrarySort.album);
  });

  test('invalid or future rules cannot broaden membership', () {
    expect(SmartPlaylistDefinition(rules: []).validate(), isNotNull);
    expect(
      const SmartRule(
        SmartField.year,
        SmartOperator.atLeast,
        'oops',
      ).validate(),
      isNotNull,
    );
    expect(
      () => SmartPlaylistDefinition.decode('{"version":2}'),
      throwsFormatException,
    );
  });
}
