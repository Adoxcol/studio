import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio/features/updates/update_backend.dart';
import 'package:studio/features/updates/update_service.dart';

class FakeBackend implements UpdateBackend {
  Completer<AvailableUpdate?> latestCall = Completer();
  Completer<void> downloadCall = Completer();
  var initializeCalls = 0;
  var latestCalls = 0;
  var downloadCalls = 0;
  var applied = false;
  Object? initializeError;

  @override
  Future<void> initialize() async {
    initializeCalls++;
    if (initializeError != null) {
      throw initializeError!;
    }
  }

  @override
  Future<AvailableUpdate?> latest() {
    latestCalls++;
    return latestCall.future;
  }

  @override
  Future<void> download() {
    downloadCalls++;
    return downloadCall.future;
  }

  @override
  Future<void> restartAndApply() async => applied = true;
}

void main() {
  group('initialize', () {
    test('check() is a no-op when service is uninitialized', () async {
      final backend = FakeBackend();
      final service = UpdateService(backend: backend);
      addTearDown(service.dispose);

      expect(service.state.initialized, isFalse);
      await service.check();

      expect(backend.latestCalls, 0);
      expect(service.state.phase, UpdatePhase.idle);
    });

    test(
      'successfully initializes backend and kicks off silent update check',
      () async {
        final backend = FakeBackend();
        final service = UpdateService(
          backend: backend,
          now: () => DateTime(2026, 9, 27, 15, 4),
        );
        addTearDown(service.dispose);

        expect(service.state.initialized, isFalse);
        backend.latestCall.complete(null);

        await service.initialize();
        expect(backend.initializeCalls, 1);
        expect(service.state.initialized, isTrue);
        expect(service.state.error, isNull);

        // Allow the unawaited check(silent: true) to settle
        await Future<void>.delayed(Duration.zero);
        expect(backend.latestCalls, 1);
        expect(service.state.upToDate, isTrue);
        expect(service.state.lastChecked, DateTime(2026, 9, 27, 15, 4));
      },
    );

    test('is idempotent and ignores subsequent initialize calls', () async {
      final backend = FakeBackend();
      final service = UpdateService(backend: backend);
      addTearDown(service.dispose);

      backend.latestCall.complete(null);
      await service.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(backend.initializeCalls, 1);
      expect(backend.latestCalls, 1);

      // Calling initialize a second time does nothing
      await service.initialize();
      expect(backend.initializeCalls, 1);
      expect(backend.latestCalls, 1);
    });

    test(
      'sets error and marks initialized when backend initialize throws',
      () async {
        final backend = FakeBackend();
        final error = StateError('native lib not found');
        backend.initializeError = error;

        final service = UpdateService(backend: backend);
        addTearDown(service.dispose);

        await service.initialize();

        expect(backend.initializeCalls, 1);
        expect(service.state.initialized, isTrue);
        expect(service.state.error, error);
        // When initialization fails, check() is not invoked
        expect(backend.latestCalls, 0);
      },
    );
  });

  late FakeBackend backend;
  late UpdateService service;
  final phases = <UpdatePhase>[];

  setUp(() async {
    backend = FakeBackend();
    service = UpdateService(
      backend: backend,
      checkTimeout: const Duration(milliseconds: 50),
      now: () => DateTime(2026, 9, 27, 15, 4),
    );
    phases.clear();
    service.addListener(() {
      if (phases.isEmpty || phases.last != service.state.phase) {
        phases.add(service.state.phase);
      }
    });
    // Let the silent startup check find nothing so tests start idle.
    backend.latestCall.complete(null);
    await service.initialize();
    await Future<void>.delayed(Duration.zero);
    backend.latestCall = Completer();
    backend.latestCalls = 0;
    phases.clear();
  });

  tearDown(() => service.dispose());

  test('reports up to date after a quick check', () async {
    final check = service.check();
    expect(service.state.checking, isTrue);
    backend.latestCall.complete(null);
    await check;
    expect(service.state.phase, UpdatePhase.idle);
    expect(service.state.upToDate, isTrue);
    expect(service.state.lastChecked, DateTime(2026, 9, 27, 15, 4));
    expect(phases, [UpdatePhase.checking, UpdatePhase.idle]);
  });

  test('checking ends when the download starts', () async {
    final check = service.check();
    backend.latestCall.complete((version: '0.6.0', notes: 'New'));
    await Future<void>.delayed(Duration.zero);
    expect(service.state.downloading, isTrue);
    expect(service.state.checking, isFalse);
    expect(service.state.version, '0.6.0');

    backend.downloadCall.complete();
    await check;
    expect(service.state.ready, isTrue);
    expect(phases, [
      UpdatePhase.checking,
      UpdatePhase.downloading,
      UpdatePhase.ready,
    ]);

    // Once ready, another click does not hit the network again.
    await service.check();
    expect(backend.latestCalls, 1);
    await service.restartAndUpdate();
    expect(backend.applied, isTrue);
  });

  test('a stalled server times out instead of checking forever', () async {
    await service.check();
    expect(service.state.phase, UpdatePhase.idle);
    expect(service.state.timedOut, isTrue);
    expect(service.state.error, isNotNull);

    // A late answer from the abandoned request is ignored.
    backend.latestCall.complete((version: '9.9.9', notes: null));
    await Future<void>.delayed(Duration.zero);
    expect(service.state.phase, UpdatePhase.idle);
    expect(backend.downloadCalls, 0);

    // Retrying clears the error.
    backend.latestCall = Completer();
    final retry = service.check();
    expect(service.state.error, isNull);
    expect(service.state.timedOut, isFalse);
    backend.latestCall.complete(null);
    await retry;
    expect(service.state.upToDate, isTrue);
  });

  test('ignores clicks while busy', () async {
    final first = service.check();
    await service.check();
    expect(backend.latestCalls, 1);
    backend.latestCall.complete(null);
    await first;
  });

  test('a failed download returns to idle with an error', () async {
    final check = service.check();
    backend.latestCall.complete((version: '0.6.0', notes: null));
    await Future<void>.delayed(Duration.zero);
    backend.downloadCall.completeError(StateError('disk full'));
    await check;
    expect(service.state.phase, UpdatePhase.idle);
    expect(service.state.error, isA<StateError>());
  });

  test('silent checks never surface errors', () async {
    final check = service.check(silent: true);
    backend.latestCall.completeError(StateError('offline'));
    await check;
    expect(service.state.error, isNull);
    await service.check(silent: true);
    expect(service.state.timedOut, isFalse);
  });
}
