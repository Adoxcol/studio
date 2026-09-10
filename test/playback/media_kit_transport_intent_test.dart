import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/media_kit_engine.dart';

// Exercise the real engine orchestration without opening a physical device.
class _Signals extends Fake implements PlayerStream {
  final audio = StreamController<AudioParams>.broadcast();
  final playState = StreamController<bool>.broadcast();
  @override
  Stream<AudioParams> get audioParams => audio.stream;
  @override
  Stream<bool> get playing => playState.stream;
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  Stream<String> get error => const Stream.empty();
  @override
  Stream<PlayerLog> get log => const Stream.empty();
}

class _Player extends Fake implements Player {
  final signals = _Signals();
  final opening = Completer<void>();
  final decoder = Completer<void>();
  final closed = Completer<void>();
  var playing = false;
  int playCalls = 0;
  @override
  PlatformPlayer? get platform => null;
  @override
  PlayerStream get stream => signals;
  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    opening.complete();
    await decoder.future;
    playing = play;
    signals.audio.add(const AudioParams(sampleRate: 48000, channelCount: 2));
  }

  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    signals.playState.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    signals.playState.add(false);
  }

  @override
  Future<void> dispose() async {
    await signals.audio.close();
    await signals.playState.close();
    closed.complete();
  }
}

void main() {
  for (final beforeOpen in [false, true]) {
    test(
      'native orchestration retains pause during opening (early: $beforeOpen)',
      () async {
        final player = _Player();
        final engine = MediaKitAudioEngine(player: player);
        addTearDown(() async {
          engine.dispose();
          await player.closed.future;
        });
        final opening = engine.play(Uri.parse('file:///music/a.flac'));
        if (!beforeOpen) await player.opening.future;
        await engine.pause();
        player.decoder.complete();
        await opening;
        expect(player.playing, isFalse);
        expect(
          player.playCalls,
          0,
          reason: 'No brief restart after the decoder becomes ready',
        );
      },
    );
  }

  test(
    'native orchestration retains resume while loading a paused session',
    () async {
      final player = _Player();
      final engine = MediaKitAudioEngine(player: player);
      addTearDown(() async {
        engine.dispose();
        await player.closed.future;
      });
      final opening = engine.load(Uri.parse('file:///music/a.flac'));
      await player.opening.future;
      await engine.resume();
      player.decoder.complete();
      await opening;
      expect(player.playing, isTrue);
    },
  );
}
