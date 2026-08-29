import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:studio/playback/dsp/equalizer.dart';

Future<void> main(List<String> arguments) async {
  final libmpv = File(
    arguments.isEmpty
        ? r'build\windows\x64\runner\Debug\libmpv-2.dll'
        : arguments.single,
  ).absolute.path;
  if (!File(libmpv).existsSync()) {
    throw StateError('Missing Windows build: $libmpv');
  }

  final scratch = Directory.systemTemp.createTempSync('studio-eq-smoke-');
  final first = File('${scratch.path}\\first.wav');
  final second = File('${scratch.path}\\second.wav');
  _writeTone(first, frequency: 440);
  _writeTone(second, frequency: 660);

  MediaKit.ensureInitialized(libmpv: libmpv);
  final player = Player(
    configuration: const PlayerConfiguration(logLevel: MPVLogLevel.info),
  );
  final native = player.platform;
  if (native is! NativePlayer) {
    throw StateError('Expected NativePlayer, got ${native.runtimeType}');
  }

  final logs = <PlayerLog>[];
  final playerErrors = <String>[];
  final subscriptions = <StreamSubscription<dynamic>>[
    player.stream.log.listen((log) {
      logs.add(log);
    }),
    player.stream.error.listen((error) {
      playerErrors.add(error);
      stdout.writeln('PLAYER ERROR: $error');
    }),
  ];

  try {
    await native.command(['set', 'ao', 'wasapi']);
    await native.command(['set', 'audio-exclusive', 'no']);
    await native.command(['set', 'cache-on-disk', 'no']);
    await native.command(['set', 'cache', 'no']);
    await native.command(['set', 'af', Equalizer.afFilter(Equalizer.bass)]);
    await player.setVolume(0);

    await player.open(
      Playlist([Media(first.path), Media(second.path)]),
      play: false,
    );
    await _waitFor(
      'decoder readiness',
      () => player.state.duration > Duration.zero,
    );

    await player.play();
    await _waitFor(
      'initial playback clock',
      () => player.state.position >= const Duration(milliseconds: 250),
    );

    await native.command(Equalizer.afCommand(4, 2.51));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    await player.seek(const Duration(milliseconds: 1200));
    await _waitFor(
      'seek',
      () => player.state.position >= const Duration(milliseconds: 1150),
    );

    await player.pause();
    await _waitFor('pause', () => !player.state.playing);
    final pausedAt = player.state.position;
    await player.play();
    await _waitFor(
      'resume',
      () =>
          player.state.position >= pausedAt + const Duration(milliseconds: 150),
    );

    await player.next();
    await _waitFor(
      'next track',
      () =>
          player.state.playlist.index == 1 &&
          player.state.position >= const Duration(milliseconds: 150),
    );
    await native.command(Equalizer.afCommand(8, -3));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final activeFilters = await native.getProperty('af');
    if (!activeFilters.contains('studio_eq')) {
      throw StateError('EQ chain is not active: $activeFilters');
    }

    final rejected = logs.where((log) {
      final text = '${log.prefix} ${log.text}'.toLowerCase();
      final benignOsc = text.contains(
        'property not found _setproperty(osc, 1)',
      );
      return !benignOsc &&
          (log.level == 'fatal' ||
              log.level == 'error' ||
              text.contains("'aresample' filter not present") ||
              text.contains('failed to configure the filter graph') ||
              text.contains('disabling filter') ||
              text.contains('invalid parameter') ||
              text.contains('af-command: has only'));
    }).toList();
    if (playerErrors.isNotEmpty || rejected.isNotEmpty) {
      for (final log in rejected.take(12)) {
        stdout.writeln(
          'REJECTED ${log.level}: ${log.prefix}: ${log.text.trim()}',
        );
      }
      throw StateError(
        'Playback produced ${playerErrors.length} player errors and '
        '${rejected.length} rejected mpv log messages.',
      );
    }

    stdout.writeln('PLAYBACK_EQ_SMOKE_OK');
  } finally {
    await player.stop();
    await player.dispose();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    scratch.deleteSync(recursive: true);
  }
}

Future<void> _waitFor(String operation, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out waiting for $operation');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void _writeTone(File file, {required double frequency}) {
  const sampleRate = 48000;
  const channels = 2;
  const bitsPerSample = 16;
  const seconds = 4;
  const bytesPerSample = bitsPerSample ~/ 8;
  const frameCount = sampleRate * seconds;
  const dataLength = frameCount * channels * bytesPerSample;
  final bytes = ByteData(44 + dataLength);

  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  bytes.setUint16(32, channels * bytesPerSample, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);

  for (var frame = 0; frame < frameCount; frame++) {
    final sample =
        (math.sin(2 * math.pi * frequency * frame / sampleRate) * 10000)
            .round();
    final offset = 44 + frame * channels * bytesPerSample;
    bytes.setInt16(offset, sample, Endian.little);
    bytes.setInt16(offset + bytesPerSample, sample, Endian.little);
  }
  file.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
}
