import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/lyrics/lrc.dart';
import 'package:studio/lyrics/lyrics_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class LyricsPane extends ConsumerWidget {
  const LyricsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(currentLyricsProvider);
    return lyrics.when(
      data: (document) {
        if (document == null) return const SizedBox.shrink();
        if (document.instrumental) {
          return const _LyricsMessage(text: 'Instrumental');
        }
        if (document.missing || !document.hasLines) {
          return const _LyricsMessage(text: 'No lyrics for this track.');
        }
        return LyricsScroller(document: document);
      },
      loading: () => const _LyricsMessage(text: 'Looking up lyrics…'),
      error: (_, _) => const _LyricsMessage(text: 'Lyrics unavailable.'),
    );
  }
}

class LyricsScroller extends ConsumerStatefulWidget {
  const LyricsScroller({super.key, required this.document});

  static const double lineExtent = 40;

  final LyricsDocument document;

  @override
  ConsumerState<LyricsScroller> createState() => _LyricsScrollerState();
}

class _LyricsScrollerState extends ConsumerState<LyricsScroller> {
  final _controller = ScrollController();
  var _lastIndex = -1;

  @override
  void didUpdateWidget(covariant LyricsScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _lastIndex = -1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _center(int index) {
    if (!mounted) return;
    if (!_controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _center(index);
      });
      return;
    }
    if (index == _lastIndex) return;
    final first = _lastIndex < 0;
    _lastIndex = index;
    final max = _controller.position.maxScrollExtent;
    final target = (index * LyricsScroller.lineExtent).clamp(0.0, max);
    if ((_controller.offset - target).abs() < 0.5) return;
    if (first) {
      _controller.jumpTo(target);
      return;
    }
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final position = ref.watch(
      playbackControllerProvider.select((s) => s.position),
    );
    final lines = widget.document.lines;
    final current = widget.document.synced
        ? LyricsDocument.currentIndex(lines, position)
        : -1;
    final targetIndex = current < 0 ? 0 : current;
    if (targetIndex != _lastIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _center(targetIndex));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad =
            (constraints.maxHeight / 2) - (LyricsScroller.lineExtent / 2);
        return ListView.builder(
          controller: _controller,
          padding: EdgeInsets.symmetric(vertical: pad < 0 ? 0 : pad),
          itemExtent: LyricsScroller.lineExtent,
          addAutomaticKeepAlives: false,
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final active = index == current;
            final line = lines[index];
            final text = Align(
              alignment: Alignment.center,
              child: Text(
                line.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: active ? palette.accent : palette.inkMuted,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            );
            if (!widget.document.synced) return text;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: ValueKey<String>('lyric-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  unawaited(
                    ref
                        .read(playbackControllerProvider.notifier)
                        .seekTo(line.start),
                  );
                },
                child: SizedBox(height: LyricsScroller.lineExtent, child: text),
              ),
            );
          },
        );
      },
    );
  }
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
        ),
      ),
    );
  }
}
