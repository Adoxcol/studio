import 'dart:async';

/// Coalesce invalidations *before* executing an expensive query. At most one
/// query runs at a time, and changes during a query always trigger a trailing
/// refresh. Cancellation drops late results and releases the update listener.
Stream<T> watchCoalescedQuery<T>(
  Stream<Object?> changes,
  Future<T> Function() query, {
  Duration window = const Duration(milliseconds: 250),
}) {
  late StreamController<T> controller;
  StreamSubscription<Object?>? subscription;
  Timer? cooldown;
  var running = false;
  var dirty = true;
  var cancelled = false;
  var sourceDone = false;

  Future<void> refresh() async {
    if (cancelled || running || cooldown != null) return;
    if (!dirty) {
      if (sourceDone) await controller.close();
      return;
    }
    dirty = false;
    running = true;
    cooldown = Timer(window, () {
      cooldown = null;
      unawaited(refresh());
    });
    try {
      final result = await query();
      if (!cancelled) controller.add(result);
    } catch (error, stack) {
      if (!cancelled) controller.addError(error, stack);
    } finally {
      running = false;
      if (!cancelled && cooldown == null) unawaited(refresh());
    }
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = changes.listen(
        (_) {
          dirty = true;
          unawaited(refresh());
        },
        onError: controller.addError,
        onDone: () {
          sourceDone = true;
          unawaited(refresh());
        },
      );
      unawaited(refresh());
    },
    onCancel: () async {
      cancelled = true;
      cooldown?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}
