import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/listening_stats/domain/listening_stats.dart';
import 'package:studio/features/listening_stats/presentation/listening_stats_providers.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// "3 h 25 m", "45 m" or "0 m".
String formatListening(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0 ? '$hours h $minutes m' : '$minutes m';
}

String _plays(int count) => '$count ${count == 1 ? 'play' : 'plays'}';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  var _period = StatsPeriod.month;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final now = ref.watch(statsClockProvider)();
    final year = _year ?? now.year;
    final stats = ref.watch(listeningStatsProvider(_period));
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: ListView(
        children: [
          Text(
            'Listening stats',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              for (final period in StatsPeriod.values)
                LibraryTextAction(
                  label: period.label,
                  muted: period != _period,
                  onTap: () => setState(() => _period = period),
                ),
            ],
          ),
          const SizedBox(height: 24),
          switch (stats) {
            AsyncData(:final value) when value.plays == 0 => Text(
              'No plays recorded for this period yet. A track counts once you have heard half of it, or four minutes.',
              key: const ValueKey('stats-empty'),
              style: muted,
            ),
            AsyncData(:final value) => _PeriodStats(stats: value),
            AsyncError() => Text(
              'Could not load listening history.',
              style: muted,
            ),
            _ => const SizedBox(height: 120),
          },
          const SizedBox(height: 40),
          _YearInReview(
            year: year,
            canGoForward: year < now.year,
            onYear: (next) => setState(() => _year = next),
          ),
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('stats-clear-history'),
              onPressed: () => _confirmClear(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear listening history'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear listening history?'),
        content: const Text(
          'Every recorded play is deleted from this computer. Your music, playlists and scrobbles already sent are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('stats-clear-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(studioDatabaseProvider).clearPlayHistory();
    }
  }
}

class _PeriodStats extends StatelessWidget {
  const _PeriodStats({required this.stats});

  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatTile(label: 'Plays', value: '${stats.plays}'),
            _StatTile(
              label: 'Listening time',
              value: formatListening(stats.listening),
            ),
            _StatTile(label: 'Artists', value: '${stats.artists}'),
            _StatTile(label: 'Days listened', value: '${stats.days}'),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 32,
          runSpacing: 24,
          children: [
            _TopList(title: 'Top artists', items: stats.topArtists),
            _TopList(title: 'Top albums', items: stats.topAlbums),
            _TopList(title: 'Top tracks', items: stats.topTracks),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      excludeSemantics: true,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: palette.hairline)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.bodySmall?.copyWith(color: palette.inkMuted),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.headlineSmall?.copyWith(color: palette.ink),
            ),
            if (detail != null)
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(color: palette.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({required this.title, required this.items});

  final String title;
  final List<RankedItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.titleMedium),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              '—',
              style: theme.bodySmall?.copyWith(color: palette.inkMuted),
            ),
          for (final (i, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: theme.bodySmall?.copyWith(color: palette.inkMuted),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: item.label,
                            style: theme.bodyMedium?.copyWith(
                              color: palette.ink,
                            ),
                          ),
                          if (item.detail != null)
                            TextSpan(
                              text: '  ${item.detail}',
                              style: theme.bodySmall?.copyWith(
                                color: palette.inkMuted,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _plays(item.plays),
                    style: theme.bodySmall?.copyWith(color: palette.inkMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _YearInReview extends ConsumerWidget {
  const _YearInReview({
    required this.year,
    required this.canGoForward,
    required this.onYear,
  });

  final int year;
  final bool canGoForward;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.copyWith(color: palette.inkMuted);
    final review = ref.watch(yearInReviewProvider(year));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$year in review', style: theme.titleLarge),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Previous year',
              onPressed: () => onYear(year - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Next year',
              onPressed: canGoForward ? () => onYear(year + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        switch (review) {
          AsyncData(:final value) when value.plays == 0 => Text(
            'Nothing recorded in $year.',
            key: const ValueKey('review-empty'),
            style: muted,
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatTile(
                    label: 'Minutes listened',
                    value: '${value.listening.inMinutes}',
                    detail: _plays(value.plays),
                  ),
                  if (value.topArtists.firstOrNull case final artist?)
                    _StatTile(
                      label: 'Top artist',
                      value: artist.label,
                      detail: _plays(artist.plays),
                    ),
                  if (value.topTracks.firstOrNull case final track?)
                    _StatTile(
                      label: 'Top track',
                      value: track.label,
                      detail: track.detail,
                    ),
                  _StatTile(
                    label: 'Longest streak',
                    value:
                        '${value.longestStreak} ${value.longestStreak == 1 ? 'day' : 'days'}',
                  ),
                  if (value.busiestDay case final day?)
                    _StatTile(
                      label: 'Busiest day',
                      value:
                          '${_months[day.month - 1].substring(0, 3)} ${day.day}',
                      detail: _plays(value.busiestDayPlays),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Plays per month', style: theme.titleSmall),
              const SizedBox(height: 12),
              _MonthBars(playsByMonth: value.playsByMonth),
            ],
          ),
          AsyncError() => Text('Could not load $year.', style: muted),
          _ => const SizedBox(height: 120),
        },
      ],
    );
  }
}

/// One series, one hue: thin accent bars with rounded tops on a baseline,
/// month initials below and a tooltip per month.
class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.playsByMonth});

  final List<int> playsByMonth;

  static const _plotHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: palette.inkMuted);
    final peak = playsByMonth.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      width: 12 * 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var month = 0; month < 12; month++)
            Expanded(
              child: Tooltip(
                message: '${_months[month]}: ${_plays(playsByMonth[month])}',
                child: Semantics(
                  container: true,
                  label: '${_months[month]}: ${_plays(playsByMonth[month])}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: _plotHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 0.55,
                            heightFactor: peak == 0
                                ? 0
                                : playsByMonth[month] / peak,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.accent,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(height: 1, color: palette.hairline),
                      const SizedBox(height: 4),
                      Text(_months[month].substring(0, 1), style: labelStyle),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
