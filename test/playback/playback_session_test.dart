import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/playback/playback_queue.dart';
import 'package:studio/playback/playback_session.dart';
import 'package:studio/playback/playback_session_store.dart';

void main() {
  test('fromJson round-trips queue, index, and playhead', () {
    const session = PlaybackSession(
      queueIds: [10, 20, 30],
      index: 1,
      position: Duration(minutes: 1, seconds: 12),
      repeat: QueueRepeatMode.all,
      shuffle: true,
    );
    expect(PlaybackSession.fromJson(session.toJson()), isA<PlaybackSession>());
    final restored = PlaybackSession.fromJson(session.toJson());
    expect(restored.queueIds, [10, 20, 30]);
    expect(restored.index, 1);
    expect(restored.currentId, 20);
    expect(restored.position, const Duration(minutes: 1, seconds: 12));
    expect(restored.repeat, QueueRepeatMode.all);
    expect(restored.shuffle, isTrue);
  });

  test('keepKnown drops missing tracks and keeps the same current id', () {
    const session = PlaybackSession(
      queueIds: [1, 2, 3, 4],
      index: 2,
      position: Duration(seconds: 40),
    );
    final kept = session.keepKnown({2, 3, 9});
    expect(kept.queueIds, [2, 3]);
    expect(kept.currentId, 3);
    expect(kept.position, const Duration(seconds: 40));
  });

  test('unknown repeat name is off', () {
    expect(QueueRepeatMode.fromName('nope'), QueueRepeatMode.off);
    expect(QueueRepeatMode.fromName('one'), QueueRepeatMode.one);
  });

  test('keepKnown clears the session when every id is gone', () {
    const session = PlaybackSession(queueIds: [1, 2], index: 0);
    expect(session.keepKnown({9}).isEmpty, isTrue);
  });

  test('keepKnown resets playhead when the current track is gone', () {
    const session = PlaybackSession(
      queueIds: [1, 2, 3],
      index: 0,
      position: Duration(seconds: 9),
    );
    final kept = session.keepKnown({2, 3});
    expect(kept.currentId, 2);
    expect(kept.position, Duration.zero);
  });

  test('file store round-trips a session', () {
    final file = File('${Directory.systemTemp.path}/studio_session_test.json');
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    const session = PlaybackSession(
      queueIds: [7, 8],
      index: 1,
      position: Duration(milliseconds: 1500),
    );
    FilePlaybackSessionStore(file).save(session);
    final loaded = FilePlaybackSessionStore(file).load();
    expect(loaded.queueIds, [7, 8]);
    expect(loaded.index, 1);
    expect(loaded.position, const Duration(milliseconds: 1500));
  });

  test('missing file loads empty', () {
    final file = File(
      '${Directory.systemTemp.path}/studio_session_missing.json',
    );
    if (file.existsSync()) file.deleteSync();
    expect(FilePlaybackSessionStore(file).load().isEmpty, isTrue);
  });
}
