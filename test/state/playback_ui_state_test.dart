import 'package:flutter_test/flutter_test.dart';
import 'package:studio/state/playback_provider.dart';

void main() {
  test('upcomingIds are the tracks after the current one', () {
    const idle = PlaybackUiState();
    expect(idle.upcomingIds, isEmpty);

    const playing = PlaybackUiState(
      trackId: 2,
      title: 'Current',
      queueIds: [1, 2, 3, 4],
    );
    expect(playing.upcomingIds, [3, 4]);

    const last = PlaybackUiState(
      trackId: 4,
      title: 'Last',
      queueIds: [1, 2, 3, 4],
    );
    expect(last.upcomingIds, isEmpty);
  });
}
