import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/nav_state.dart';

class StudioNavNotifier extends Notifier<StudioDestination> {
  @override
  StudioDestination build() => StudioDestination.library;

  void select(StudioDestination destination) => state = destination;
}

final studioNavProvider =
    NotifierProvider<StudioNavNotifier, StudioDestination>(
  StudioNavNotifier.new,
);
