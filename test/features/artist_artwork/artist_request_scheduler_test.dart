import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/artist_artwork/data/artist_request_scheduler.dart';
import 'package:studio/features/artist_artwork/data/artist_service_exception.dart';

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ArtistRequestScheduler scheduler;
  setUp(
    () => scheduler = ArtistRequestScheduler(metadataSpacing: Duration.zero),
  );
  tearDown(() => scheduler.close());

  Future<T> request<T>(
    String host,
    Future<T> Function() operation, {
    bool image = false,
    String artist = 'Aria',
    bool Function()? cancelled,
  }) => scheduler.run(
    Uri.https(host, '/test'),
    operation,
    artist: artist,
    image: image,
    cancelled: cancelled ?? () => false,
  );

  test('concurrent metadata requests stay serial and paced per host', () async {
    scheduler.close();
    scheduler = ArtistRequestScheduler(
      metadataSpacing: const Duration(milliseconds: 25),
    );
    final times = <DateTime>[];
    var active = 0;
    var peak = 0;
    await Future.wait(
      List.generate(
        4,
        (_) => request('musicbrainz.org', () async {
          active++;
          if (active > peak) peak = active;
          times.add(DateTime.now());
          await Future<void>.delayed(const Duration(milliseconds: 5));
          active--;
        }),
      ),
    );
    expect(peak, 1);
    for (var i = 1; i < times.length; i++) {
      expect(
        times[i].difference(times[i - 1]).inMilliseconds,
        greaterThanOrEqualTo(24),
      );
    }
  });

  test(
    'priority changes reorder requests already waiting for a provider',
    () async {
      final gate = Completer<void>();
      final order = <String>[];
      final first = request('musicbrainz.org', () => gate.future);
      final background = request(
        'musicbrainz.org',
        () async => order.add('background'),
        artist: 'Background',
      );
      final visible = request(
        'musicbrainz.org',
        () async => order.add('visible'),
        artist: 'Visible',
      );
      scheduler.setPriority('VISIBLE', true);
      gate.complete();
      await Future.wait([first, background, visible]);
      expect(order, ['visible', 'background']);
    },
  );

  test(
    'provider failure rejects its waiting requests but not other hosts',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final first = request('musicbrainz.org', () async {
        calls++;
        await gate.future;
        throw ArtistServiceException('musicbrainz.org', 503);
      });
      final queued = request('musicbrainz.org', () async => calls++);
      final firstError = expectLater(
        first,
        throwsA(isA<ArtistServiceException>()),
      );
      final queuedError = expectLater(
        queued,
        throwsA(isA<ArtistServiceException>()),
      );
      expect(
        await request('webservice.fanart.tv', () async => 'metadata'),
        'metadata',
      );
      expect(
        await request('assets.fanart.tv', () async => 'image', image: true),
        'image',
      );
      gate.complete();
      await Future.wait([firstError, queuedError]);
      expect(calls, 1);
      expect(
        await request('commons.wikimedia.org', () async => 'available'),
        'available',
      );
    },
  );

  test('image transfers share one bounded pool across all CDNs', () async {
    final gates = List.generate(9, (_) => Completer<void>());
    var started = 0;
    var active = 0;
    var peak = 0;
    final downloads = List.generate(
      9,
      (i) => request('cdn$i.example', () async {
        started++;
        active++;
        if (active > peak) peak = active;
        await gates[i].future;
        active--;
      }, image: true),
    );
    await _flush();
    expect(started, 3);
    gates.first.complete();
    await _flush();
    expect(started, 4);
    for (final gate in gates.skip(1)) {
      gate.complete();
    }
    await Future.wait(downloads);
    expect(peak, 3);
    expect(started, 9);
  });

  test(
    'metadata quota and cooldown do not block same-host image files',
    () async {
      final metadata = request('www.theaudiodb.com', () async {
        throw ArtistServiceException('www.theaudiodb.com', 429);
      });
      await expectLater(metadata, throwsA(isA<ArtistServiceException>()));
      expect(
        await request(
          'www.theaudiodb.com',
          () async => 'portrait',
          image: true,
        ),
        'portrait',
      );
    },
  );

  test(
    'concurrent success cannot erase Retry-After and cancellation keeps it',
    () async {
      var clock = DateTime.utc(2026, 8, 31);
      scheduler.close();
      scheduler = ArtistRequestScheduler(clock: () => clock);
      final deadline = clock.add(const Duration(minutes: 3));
      final gate = Completer<void>();
      final success = request(
        'assets.fanart.tv',
        () => gate.future,
        image: true,
      );
      await expectLater(
        request('assets.fanart.tv', () async {
          throw ArtistServiceException(
            'assets.fanart.tv',
            429,
            retryAfter: deadline,
          );
        }, image: true),
        throwsA(isA<ArtistServiceException>()),
      );
      gate.complete();
      await success;
      scheduler.cancel();
      var sent = false;
      await expectLater(
        request('assets.fanart.tv', () async {
          sent = true;
        }, image: true),
        throwsA(
          isA<ArtistServiceException>().having(
            (e) => e.retryAfter,
            'deadline',
            deadline,
          ),
        ),
      );
      expect(sent, isFalse);
      clock = deadline;
      await request('assets.fanart.tv', () async {
        sent = true;
      }, image: true);
      expect(sent, isTrue);
    },
  );

  test(
    'cancel clears queued waits without making requests or poisoning recovery',
    () async {
      final gate = Completer<void>();
      var cancelled = false;
      var sends = 0;
      final active = request(
        'musicbrainz.org',
        () => gate.future,
        cancelled: () => cancelled,
      );
      final queued = request('musicbrainz.org', () async {
        sends++;
      }, cancelled: () => cancelled);
      final activeError = expectLater(active, throwsStateError);
      final queuedError = expectLater(queued, throwsStateError);
      cancelled = true;
      scheduler.cancel();
      gate.complete();
      await Future.wait([activeError, queuedError]);
      expect(sends, 0);
      cancelled = false;
      await request('musicbrainz.org', () async {
        sends++;
      });
      expect(sends, 1);
    },
  );
}
