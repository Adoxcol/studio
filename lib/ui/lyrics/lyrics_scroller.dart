import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studio/lyrics/lrc.dart';
import 'package:studio/lyrics/lyrics_providers.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

class LyricsPane extends ConsumerWidget {
  const LyricsPane({super.key, this.immersive = false});

  final bool immersive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyrics = ref.watch(currentLyricsProvider);
    return lyrics.when(
      data: (document) {
        if (document == null) return const SizedBox.shrink();
        if (document.instrumental) {
          return _LyricsMessage(text: 'Instrumental', immersive: immersive);
        }
        if (document.missing || !document.hasLines) {
          return _LyricsMessage(
            text: 'No lyrics for this track.',
            immersive: immersive,
          );
        }
        return LyricsScroller(document: document, immersive: immersive);
      },
      loading: () =>
          _LyricsMessage(text: 'Looking up lyrics…', immersive: immersive),
      error: (_, _) =>
          _LyricsMessage(text: 'Lyrics unavailable.', immersive: immersive),
    );
  }
}

class LyricsScroller extends ConsumerStatefulWidget {
  const LyricsScroller({
    super.key,
    required this.document,
    this.immersive = false,
  });

  static const double lineExtent = 40;

  final LyricsDocument document;
  final bool immersive;

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
    final target = (index * _lineExtent).clamp(0.0, max);
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
        final lineExtent = _lineExtent;
        final pad = (constraints.maxHeight / 2) - (lineExtent / 2);
        return ListView.builder(
          controller: _controller,
          padding: EdgeInsets.symmetric(vertical: pad < 0 ? 0 : pad),
          itemExtent: lineExtent,
          addAutomaticKeepAlives: false,
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final active = index == current;
            final line = lines[index];
            final text = Align(
              alignment: Alignment.center,
              child: Text(
                line.text,
                maxLines: widget.immersive ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: widget.immersive
                    ? TextStyle(
                        color: active ? Colors.white : Colors.white60,
                        fontSize: active ? 30 : 23,
                        height: 1.18,
                        letterSpacing: active ? -0.35 : -0.15,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        leadingDistribution: TextLeadingDistribution.even,
                        shadows: const [
                          Shadow(
                            color: Color(0xcc000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                          Shadow(color: Color(0xaa000000), blurRadius: 14),
                          Shadow(color: Color(0x66000000), blurRadius: 28),
                        ],
                      )
                    : Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                child: SizedBox(height: lineExtent, child: text),
              ),
            );
          },
        );
      },
    );
  }

  double get _lineExtent => widget.immersive ? 76 : LyricsScroller.lineExtent;
}

class _LyricsMessage extends StatelessWidget {
  const _LyricsMessage({required this.text, this.immersive = false});

  final String text;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: immersive
              ? const TextStyle(color: Colors.white70, fontSize: 23)
              : Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
        ),
      ),
    );
  }
}
