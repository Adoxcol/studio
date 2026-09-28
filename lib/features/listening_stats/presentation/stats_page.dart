import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/features/artist_artwork/presentation/artist_portrait.dart';
import 'package:studio/features/listening_stats/domain/listening_stats.dart';
import 'package:studio/features/listening_stats/presentation/listening_stats_providers.dart';
import 'package:studio/state/library_providers.dart';
import 'package:studio/theming/genre_color.dart';
import 'package:studio/theming/studio_palette.dart';
import 'package:studio/ui/library_browser/library_text_action.dart';
import 'package:studio/ui/now_playing/cover_art.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];

/// "3 h 25 m", "45 m" or "0 m".
String formatListening(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0 ? '$hours h $minutes m' : '$minutes m';
}

String _plays(int count) => '$count ${count == 1 ? 'play' : 'plays'}';

String _hour(int hour) => switch (hour) {
  0 => '12 am',
  12 => '12 pm',
  < 12 => '$hour am',
  _ => '${hour - 12} pm',
};

/// "+25% vs previous 30 days", or null when there is nothing to compare.
String? _change(num now, num? before, String span) {
  if (before == null || before == 0) return null;
  final percent = ((now - before) / before * 100).round();
  if (percent == 0) return 'Same as previous $span';
  return '${percent > 0 ? '+' : ''}$percent% vs previous $span';
}

String _span(StatsPeriod period) => switch (period) {
  StatsPeriod.week => '7 days',
  StatsPeriod.month => '30 days',
  StatsPeriod.year => 'period',
  StatsPeriod.all => '',
};

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
    final report = ref.watch(listeningStatsProvider(_period));
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: palette.inkMuted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      children: [
        Text(
          'Listening stats',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        // One filter row scopes everything in the period section.
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
        switch (report) {
          AsyncData(:final value) when value.stats.plays == 0 => Text(
            'No plays recorded for this period yet. A track counts once you have heard half of it, or four minutes.',
            key: const ValueKey('stats-empty'),
            style: muted,
          ),
          AsyncData(:final value) => _PeriodStats(
            report: value,
            span: _span(_period),
          ),
          AsyncError() => Text(
            'Could not load listening history.',
            style: muted,
          ),
          _ => const SizedBox(height: 120),
        },
        const SizedBox(height: 48),
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

/// Lays children out in [columns] equal columns, wrapping to fewer when the
/// page is narrow.
class _Columns extends StatelessWidget {
  const _Columns({required this.children, this.minWidth = 320});

  final List<Widget> children;
  final double minWidth;

  static const _gap = 32.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = ((constraints.maxWidth + _gap) / (minWidth + _gap))
            .floor()
            .clamp(1, children.length);
        final width = (constraints.maxWidth - _gap * (fit - 1)) / fit;
        return Wrap(
          spacing: _gap,
          runSpacing: 32,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.titleMedium),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.bodySmall?.copyWith(color: palette.inkMuted),
            ),
        ],
      ),
    );
  }
}

class _PeriodStats extends ConsumerWidget {
  const _PeriodStats({required this.report, required this.span});

  final PeriodReport report;
  final String span;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = report.stats;
    final previous = report.previous;
    final tracksById = ref.watch(libraryTracksByIdProvider);
    String? art(RankedItem item) =>
        item.trackId == null ? null : tracksById[item.trackId]?.artworkPath;
    final newArtists = stats.newArtists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatTile(
              label: 'Plays',
              value: '${stats.plays}',
              change: _change(stats.plays, previous?.plays, span),
            ),
            _StatTile(
              label: 'Listening time',
              value: formatListening(stats.listening),
              change: _change(
                stats.listening.inMinutes,
                previous?.listening.inMinutes,
                span,
              ),
            ),
            _StatTile(
              label: 'Days listened',
              value: '${stats.days}',
              detail: '${formatListening(stats.perDay)} a day',
            ),
            _StatTile(
              label: 'Artists',
              value: '${stats.artists}',
              detail: previous == null
                  ? null
                  : '${newArtists.length} new to you',
            ),
            _StatTile(label: 'Albums', value: '${stats.albums}'),
            _StatTile(label: 'Tracks', value: '${stats.tracks}'),
          ],
        ),
        const SizedBox(height: 32),
        _Spotlight(stats: stats, artworkOf: art),
        const SizedBox(height: 40),
        _Columns(
          children: [
            _TopList(
              title: 'Top artists',
              items: stats.topArtists,
              thumbnail: (item) => ArtistPortrait(artist: item.label, size: 40),
            ),
            _TopList(
              title: 'Top albums',
              items: stats.topAlbums,
              thumbnail: (item) => _Cover(path: art(item)),
            ),
            _TopList(
              title: 'Top tracks',
              items: stats.topTracks,
              thumbnail: (item) => _Cover(path: art(item)),
            ),
          ],
        ),
        const SizedBox(height: 40),
        _Columns(
          minWidth: 360,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Time of day', subtitle: 'Plays by hour'),
                _Bars(
                  values: stats.playsByHour,
                  label: (i) => _hour(i),
                  axisLabel: (i) => i % 6 == 0 ? _hour(i) : null,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Day of week', subtitle: 'Plays by day'),
                _Bars(
                  values: stats.playsByWeekday,
                  label: (i) => _weekdays[i],
                  axisLabel: (i) => _weekdays[i].substring(0, 3),
                ),
              ],
            ),
          ],
        ),
        if (stats.topGenres.isNotEmpty || newArtists.isNotEmpty) ...[
          const SizedBox(height: 40),
          _Columns(
            minWidth: 360,
            children: [
              if (stats.topGenres.isNotEmpty)
                _GenreBreakdown(genres: stats.topGenres),
              if (newArtists.isNotEmpty)
                _TopList(
                  title: 'New to you',
                  subtitle: 'Artists you first played in this period',
                  items: newArtists.take(5).toList(),
                  thumbnail: (item) =>
                      ArtistPortrait(artist: item.label, size: 40),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.path, this.size = 40});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size > 60 ? 8 : 4),
    child: CoverArt(path: path, size: size),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.detail,
    this.change,
  });

  final String label;
  final String value;
  final String? detail;

  /// Change against the previous period, shown under the value.
  final String? change;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.copyWith(color: palette.inkMuted);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: '$label: $value${detail == null ? '' : ', $detail'}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: muted),
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
                    style: muted,
                  ),
              ],
            ),
          ),
          if (change != null) ...[
            const SizedBox(height: 4),
            Text(
              change!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

/// The period's number one artist, album and track, with large artwork.
class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.stats, required this.artworkOf});

  final ListeningStats stats;
  final String? Function(RankedItem) artworkOf;

  @override
  Widget build(BuildContext context) {
    final artist = stats.topArtists.firstOrNull;
    final album = stats.topAlbums.firstOrNull;
    final track = stats.topTracks.firstOrNull;
    return _Columns(
      minWidth: 280,
      children: [
        if (artist != null)
          _SpotlightCard(
            kind: 'Most played artist',
            item: artist,
            art: ArtistPortrait(artist: artist.label, size: 88),
          ),
        if (album != null)
          _SpotlightCard(
            kind: 'Most played album',
            item: album,
            art: _Cover(path: artworkOf(album), size: 88),
          ),
        if (track != null)
          _SpotlightCard(
            kind: 'Most played track',
            item: track,
            art: _Cover(path: artworkOf(track), size: 88),
          ),
      ],
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    required this.kind,
    required this.item,
    required this.art,
  });

  final String kind;
  final RankedItem item;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.copyWith(color: palette.inkMuted);
    return Semantics(
      container: true,
      label: '$kind: ${item.label}, ${_plays(item.plays)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.hairline),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.accent.withValues(alpha: 0.10), palette.bg],
          ),
        ),
        child: Row(
          children: [
            art,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.toUpperCase(), style: muted),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleLarge?.copyWith(color: palette.ink),
                  ),
                  if (item.detail != null)
                    Text(
                      item.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  const SizedBox(height: 4),
                  Text(_plays(item.plays), style: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ranked top-10 list with artwork and a bar for plays against number one.
class _TopList extends StatelessWidget {
  const _TopList({
    required this.title,
    required this.items,
    required this.thumbnail,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<RankedItem> items;
  final Widget Function(RankedItem item) thumbnail;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.copyWith(color: palette.inkMuted);
    final best = items.firstOrNull?.plays ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title, subtitle: subtitle),
        if (items.isEmpty) Text('—', style: muted),
        for (final (i, item) in items.indexed)
          Semantics(
            container: true,
            label:
                '${i + 1}. ${item.label}${item.detail == null ? '' : ', ${item.detail}'}, ${_plays(item.plays)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: muted?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  thumbnail(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodyMedium?.copyWith(
                                  color: palette.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_plays(item.plays), style: muted),
                          ],
                        ),
                        if (item.detail != null)
                          Text(
                            item.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        const SizedBox(height: 4),
                        _ShareBar(share: item.plays / best),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A thin single-hue bar on a hairline track.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: palette.hairlineSoft),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: share.clamp(0.02, 1.0),
              child: ColoredBox(color: palette.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Genres ranked by plays. The bars share the accent (one series); each
/// genre's own colour appears only as its identity dot.
class _GenreBreakdown extends StatelessWidget {
  const _GenreBreakdown({required this.genres});

  final List<RankedItem> genres;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final muted = theme.bodySmall?.copyWith(color: palette.inkMuted);
    final brightness = Theme.of(context).brightness;
    final best = genres.first.plays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Top genres'),
        for (final genre in genres.take(8))
          Semantics(
            container: true,
            label: '${genre.label}: ${_plays(genre.plays)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: genreColors(genre.label, brightness).accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: Text(
                      genre.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium?.copyWith(color: palette.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _ShareBar(share: genre.plays / best)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 64,
                    child: Text(
                      _plays(genre.plays),
                      textAlign: TextAlign.right,
                      style: muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
              const _SectionTitle('Plays per month'),
              _Bars(
                values: value.playsByMonth,
                label: (i) => _months[i],
                axisLabel: (i) => _months[i].substring(0, 1),
                maxWidth: 12 * 40,
              ),
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
/// sparse axis labels below and a tooltip per bar.
class _Bars extends StatelessWidget {
  const _Bars({
    required this.values,
    required this.label,
    required this.axisLabel,
    this.maxWidth,
  });

  final List<int> values;

  /// Full name of bar i, for its tooltip and screen readers.
  final String Function(int i) label;

  /// Text under bar i, or null to leave it blank.
  final String? Function(int i) axisLabel;
  final double? maxWidth;

  static const _plotHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: palette.inkMuted);
    final peak = values.fold<int>(0, (a, b) => a > b ? a : b);
    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Tooltip(
              message: '${label(i)}: ${_plays(values[i])}',
              child: Semantics(
                container: true,
                label: '${label(i)}: ${_plays(values[i])}',
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: _plotHeight,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: peak == 0 ? 0 : values[i] / peak,
                          widthFactor: 0.6,
                          // Thin marks: at most 16 px, however wide the slot.
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 16),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(height: 1, color: palette.hairline),
                    const SizedBox(height: 4),
                    Text(
                      axisLabel(i) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: labelStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
    return maxWidth == null
        ? bars
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: bars,
          );
  }
}
