import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/queue/queue_track_row.dart';

class QueuePage extends ConsumerStatefulWidget {
  const QueuePage({super.key});

  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  bool _historyExpanded = true;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final playback = ref.watch(
      playbackControllerProvider.select(
        (s) => (
          queueIds: s.queueIds,
          historyIds: s.historyIds,
          trackId: s.trackId,
        ),
      ),
    );
    final byId = ref.watch(libraryTracksByIdProvider);

    if (playback.queueIds.isEmpty && playback.historyIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        child: Text(
          'Queue is empty.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
        ),
      );
    }

    final controller = ref.read(playbackControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            label: 'QUEUE',
            action: playback.queueIds.length > 1 ? 'Clear upcoming' : null,
            onAction: controller.clearUpcoming,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemExtent: QueueTrackRow.height + 1,
              itemCount: playback.queueIds.length,
              // Flutter 3.47 deprecates this in favor of onReorderItem, which
              // is not available on the project's currently supported SDK.
              // ignore: deprecated_member_use
              onReorder: controller.moveUpcoming,
              itemBuilder: (context, index) {
                final id = playback.queueIds[index];
                final track = byId[id];
                final current = id == playback.trackId;
                return DecoratedBox(
                  key: ValueKey('queue-$index-$id'),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: palette.hairlineSoft),
                    ),
                  ),
                  child: QueueTrackRow(
                    track: track,
                    current: current,
                    onTap: current
                        ? null
                        : () => controller.playQueueIndex(index),
                    onRemove: current
                        ? null
                        : () => controller.removeUpcomingAt(index),
                    dragHandle: current
                        ? null
                        : ReorderableDragStartListener(
                            index: index,
                            child: Tooltip(
                              message: 'Reorder',
                              child: Icon(
                                Icons.drag_handle,
                                size: 19,
                                color: palette.inkMuted,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (playback.historyIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionHeader(
              label: 'HISTORY',
              action: 'Clear',
              expanded: _historyExpanded,
              onToggle: () =>
                  setState(() => _historyExpanded = !_historyExpanded),
              onAction: controller.clearHistory,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: _historyExpanded
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 210),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemExtent: QueueTrackRow.height,
                        itemCount: playback.historyIds.length,
                        itemBuilder: (context, index) {
                          final id = playback.historyIds[index];
                          return QueueTrackRow(
                            key: ValueKey('history-$index-$id'),
                            track: byId[id],
                            onTap: () => controller.playHistoryIndex(index),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.onAction,
    this.action,
    this.expanded,
    this.onToggle,
  });

  final String label;
  final String? action;
  final VoidCallback onAction;
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Row(
      children: [
        if (expanded != null)
          IconButton(
            tooltip: expanded! ? 'Collapse history' : 'Expand history',
            onPressed: onToggle,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              expanded! ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: palette.inkMuted,
            ),
          ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.inkMuted,
            letterSpacing: 1.4,
          ),
        ),
        const Spacer(),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}
