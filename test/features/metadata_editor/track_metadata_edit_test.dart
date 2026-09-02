import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/metadata_editor/domain/track_metadata_edit.dart';

import '../../helpers/tracks.dart';

void main() {
  test('normalizes optional values and describes only real changes', () {
    final track = testTrack(
      title: 'Before',
      artist: 'Aria',
      album: null,
      genre: 'Jazz',
      year: 2024,
      trackNumber: 2,
    );
    const edit = TrackMetadataEdit(
      title: ' After ',
      artist: ' Aria ',
      album: '  ',
      genre: 'Ambient',
      year: 2025,
      trackNumber: 2,
    );

    expect(edit.validate(), isNull);
    expect(edit.changesFrom(track).map((change) => change.field), [
      'Title',
      'Genre',
      'Year',
    ]);
  });

  test('rejects blank titles and invalid numeric ranges', () {
    expect(
      const TrackMetadataEdit(title: ' ').validate(),
      'Title cannot be empty.',
    );
    expect(
      const TrackMetadataEdit(title: 'Song', year: 999).validate(),
      'Year must be 1000–2100.',
    );
    expect(
      const TrackMetadataEdit(title: 'Song', trackNumber: 0).validate(),
      'Track number must be 1–9999.',
    );
  });
}
