import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/track_details/presentation/detail_context_provider.dart';
import 'package:studio/library/database.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

import '../../helpers/tracks.dart';

void main() {
  late ProviderContainer container;
  late StreamController<List<Track>> library;

  setUp(() async {
    library = StreamController<List<Track>>.broadcast();
    container = ProviderContainer(
      overrides: [
        libraryTracksProvider.overrideWith((ref) => library.stream),
        playbackControllerProvider.overrideWith(_Playback.new),
      ],
    );
    container.listen(libraryTracksProvider, (_, _) {});
    final ready = container.read(libraryTracksProvider.future);
    library.add([testTrack(id: 1), testTrack(id: 2)]);
    await ready;
  });

  tearDown(() async {
    container.dispose();
    await library.close();
  });

  _Playback playback() =>
      container.read(playbackControllerProvider.notifier) as _Playback;

  test('follows current track but not position ticks', () {
    expect(container.read(detailContextProvider).details, isNull);
    playback().emit(const PlaybackUiState(trackId: 1));
    final first = container.read(detailContextProvider);
    expect(first.details?.track.id, 1);
    playback().emit(
      const PlaybackUiState(trackId: 1, position: Duration(seconds: 12)),
    );
    expect(container.read(detailContextProvider), same(first));
    playback().emit(const PlaybackUiState(trackId: 2));
    expect(container.read(detailContextProvider).details?.track.id, 2);
  });

  test('inspection pins context until follow playback is requested', () {
    playback().emit(const PlaybackUiState(trackId: 1));
    container.read(detailSelectionProvider.notifier).inspect(2);
    expect(container.read(detailContextProvider).details?.track.id, 2);
    expect(container.read(detailContextProvider).inspected, isTrue);
    expect(container.read(playbackControllerProvider).trackId, 1);
    container.read(detailSelectionProvider.notifier).followPlayback();
    expect(container.read(detailContextProvider).details?.track.id, 1);
    expect(container.read(detailContextProvider).inspected, isFalse);
  });

  test(
    'removed inspected track falls back to playback and refreshed metadata',
    () async {
      playback().emit(const PlaybackUiState(trackId: 1));
      container.read(detailSelectionProvider.notifier).inspect(2);
      expect(container.read(detailContextProvider).details?.track.id, 2);
      library.add([testTrack(id: 1, title: 'Refreshed title')]);
      await pumpEventQueue();
      expect(
        container.read(detailContextProvider).details?.track.title,
        'Refreshed title',
      );
      expect(container.read(detailContextProvider).inspected, isFalse);
    },
  );
}

class _Playback extends PlaybackController {
  @override
  PlaybackUiState build() => const PlaybackUiState();

  void emit(PlaybackUiState value) => state = value;
}
