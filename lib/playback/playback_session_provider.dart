import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/playback/playback_session_store.dart';

final playbackSessionStoreProvider = Provider<PlaybackSessionStore>((ref) {
  return MemoryPlaybackSessionStore();
});
