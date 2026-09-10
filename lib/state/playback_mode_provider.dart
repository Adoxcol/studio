import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlaybackModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void exit() => state = false;
  void toggle() => state = !state;
}

final playbackModeProvider = NotifierProvider<PlaybackModeNotifier, bool>(
  PlaybackModeNotifier.new,
);
