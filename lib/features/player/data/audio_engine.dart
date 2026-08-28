/// Playback wrapper around media_kit. Implementation comes later.
abstract interface class AudioEngine {
  Future<void> play(String path);
  Future<void> pause();
  Future<void> stop();
}
