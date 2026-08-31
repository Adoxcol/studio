import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/nav_state.dart';

final studioNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

class StudioNavNotifier extends Notifier<StudioDestination> {
  @override
  StudioDestination build() => StudioDestination.library;

  void select(StudioDestination destination) => state = destination;
}

final studioNavProvider =
    NotifierProvider<StudioNavNotifier, StudioDestination>(
      StudioNavNotifier.new,
    );
