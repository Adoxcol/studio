import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/track_details/domain/track_details.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';

class DetailSelection {
  const DetailSelection({this.trackId});

  final int? trackId;
}

class DetailSelectionController extends Notifier<DetailSelection> {
  @override
  DetailSelection build() => const DetailSelection();

  // Each explicit inspection is also a request to reveal the Track panel,
  // including inspecting the same track again after changing tabs.
  void inspect(int trackId) => state = DetailSelection(trackId: trackId);

  void followPlayback() => state = const DetailSelection();
}

final detailSelectionProvider =
    NotifierProvider<DetailSelectionController, DetailSelection>(
      DetailSelectionController.new,
    );

class DetailContext {
  const DetailContext({required this.details, required this.inspected});

  final TrackDetails? details;
  final bool inspected;
}

/// One shared context for all three panels. Reads IDs, not playback position,
/// so progress ticks cannot rebuild the metadata or regroup the library.
final detailContextProvider = Provider<DetailContext>((ref) {
  final library = ref.watch(libraryTracksProvider).value ?? const [];
  final selectedId = ref.watch(detailSelectionProvider).trackId;
  final playingId = ref.watch(
    playbackControllerProvider.select((state) => state.trackId),
  );
  final selected = library.where((track) => track.id == selectedId).firstOrNull;
  final current =
      selected ?? library.where((track) => track.id == playingId).firstOrNull;
  return DetailContext(
    details: current == null
        ? null
        : TrackDetails(track: current, library: library),
    inspected: selected != null,
  );
});
