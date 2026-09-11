import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studio/lyrics/lrc.dart';
import 'package:studio/lyrics/lyrics_providers.dart';
import 'package:studio/state/playback_mode_provider.dart';
import 'package:studio/state/playback_provider.dart';
import 'package:studio/theming/studio_palette.dart';

/// Editorial typography-driven synchronized lyrics panel.
class EditorialLyricsPanel extends ConsumerWidget {
  const EditorialLyricsPanel({super.key, this.isFullWidth = false});

  final bool isFullWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = StudioPalette.of(context);
    final lyrics = ref.watch(currentLyricsProvider);
    final scale = ref.watch(editorialLyricsScaleProvider);
    final isSerif = ref.watch(editorialLyricsSerifProvider);
    final colorMode = ref.watch(editorialLyricsColorModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lyrics Subheader
        Padding(
          padding: const EdgeInsets.only(bottom: 12, right: 8),
          child: LayoutBuilder(
            builder: (context, headerConstraints) {
              final isNarrow = headerConstraints.maxWidth < 420;

              return Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isNarrow ? 'LYRICS' : 'SYNCHRONIZED LYRICS',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                      color: palette.accent,
                    ),
                  ),
                  const Spacer(),
                  // Font Color Selector / Follow Cover Art Accent
                  PopupMenuButton<EditorialLyricsColorMode>(
                    tooltip: 'Lyrics Font Color',
                    initialValue: colorMode,
                    onSelected: (mode) => ref
                        .read(editorialLyricsColorModeProvider.notifier)
                        .select(mode),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    color: palette.bg,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: EditorialLyricsColorMode.defaultColor,
                        child: Row(
                          children: [
                            Icon(
                              Icons.format_paint_outlined,
                              size: 16,
                              color: palette.ink,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Default Ink',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: EditorialLyricsColorMode.accentColor,
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Follow Cover Accent',
                              style: TextStyle(
                                color: palette.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: EditorialLyricsColorMode.mutedColor,
                        child: Row(
                          children: [
                            Icon(
                              Icons.format_color_text,
                              size: 16,
                              color: palette.inkMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Muted Minimal',
                              style: TextStyle(
                                color: palette.inkMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: EditorialLyricsColorMode.pureWhite,
                        child: Row(
                          children: [
                            Icon(
                              Icons.brightness_high,
                              size: 16,
                              color: palette.ink,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'High Contrast',
                              style: TextStyle(
                                color: palette.ink,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            colorMode == EditorialLyricsColorMode.accentColor
                                ? Icons.auto_awesome
                                : Icons.palette_outlined,
                            size: 13,
                            color:
                                colorMode ==
                                    EditorialLyricsColorMode.accentColor
                                ? palette.accent
                                : palette.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            colorMode == EditorialLyricsColorMode.accentColor
                                ? 'Accent'
                                : colorMode ==
                                      EditorialLyricsColorMode.mutedColor
                                ? 'Muted'
                                : colorMode ==
                                      EditorialLyricsColorMode.pureWhite
                                ? 'Bright'
                                : 'Color',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  colorMode ==
                                      EditorialLyricsColorMode.accentColor
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color:
                                  colorMode ==
                                      EditorialLyricsColorMode.accentColor
                                  ? palette.accent
                                  : palette.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('·', style: TextStyle(color: palette.hairlineStrong)),
                  const SizedBox(width: 4),
                  // Font toggle
                  if (!isNarrow) ...[
                    InkWell(
                      onTap: () => ref
                          .read(editorialLyricsSerifProvider.notifier)
                          .toggle(),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          isSerif ? 'Serif' : 'Sans',
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.inkMuted,
                            fontFamilyFallback: const ['Georgia', 'serif'],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('·', style: TextStyle(color: palette.hairlineStrong)),
                    const SizedBox(width: 6),
                  ],
                  // Font scale decrease
                  InkWell(
                    onTap: () => ref
                        .read(editorialLyricsScaleProvider.notifier)
                        .decrease(),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      child: Text(
                        'A-',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Font scale increase
                  InkWell(
                    onTap: () => ref
                        .read(editorialLyricsScaleProvider.notifier)
                        .increase(),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      child: Text(
                        'A+',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Lyrics Scroller or Empty State
        Expanded(
          child: lyrics.when(
            data: (document) {
              if (document == null) {
                return _LyricsPlaceholder(
                  message: 'No lyrics available for this track',
                  palette: palette,
                );
              }
              if (document.instrumental) {
                return _LyricsPlaceholder(
                  message: 'Instrumental Track',
                  palette: palette,
                );
              }
              if (document.missing || !document.hasLines) {
                return _LyricsPlaceholder(
                  message: 'No lyrics found',
                  palette: palette,
                );
              }
              return _EditorialLyricsScroller(
                document: document,
                scale: scale,
                isSerif: isSerif,
                colorMode: colorMode,
                isFullWidth: isFullWidth,
              );
            },
            loading: () => _LyricsPlaceholder(
              message: 'Fetching synchronized lyrics…',
              palette: palette,
            ),
            error: (_, _) => _LyricsPlaceholder(
              message: 'Lyrics currently unavailable',
              palette: palette,
            ),
          ),
        ),

        // Footer attribution
        Padding(
          padding: const EdgeInsets.only(top: 10, right: 8),
          child: LayoutBuilder(
            builder: (context, footerConstraints) {
              final isNarrow = footerConstraints.maxWidth < 620;

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      isNarrow
                          ? 'Source: Musixmatch'
                          : 'Source: Musixmatch / Local Metadata',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.inkMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Synchronized Playback',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.inkMuted,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditorialLyricsScroller extends ConsumerStatefulWidget {
  const _EditorialLyricsScroller({
    required this.document,
    required this.scale,
    required this.isSerif,
    required this.colorMode,
    required this.isFullWidth,
  });

  final LyricsDocument document;
  final double scale;
  final bool isSerif;
  final EditorialLyricsColorMode colorMode;
  final bool isFullWidth;

  @override
  ConsumerState<_EditorialLyricsScroller> createState() =>
      _EditorialLyricsScrollerState();
}

class _EditorialLyricsScrollerState
    extends ConsumerState<_EditorialLyricsScroller> {
  final _scrollController = ScrollController();
  var _lastCenteredIndex = -1;

  @override
  void didUpdateWidget(covariant _EditorialLyricsScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.document, widget.document)) {
      _lastCenteredIndex = -1;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLine(int index, double lineExtent) {
    if (!mounted || !_scrollController.hasClients) return;
    if (index == _lastCenteredIndex) return;

    final isFirst = _lastCenteredIndex < 0;
    _lastCenteredIndex = index;

    final max = _scrollController.position.maxScrollExtent;
    final target = (index * lineExtent).clamp(0.0, max);
    if ((_scrollController.offset - target).abs() < 0.5) return;

    if (isFirst) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final position = ref.watch(
      playbackControllerProvider.select((s) => s.position),
    );
    final lines = widget.document.lines;
    final current = widget.document.synced
        ? LyricsDocument.currentIndex(lines, position)
        : -1;

    final baseLineHeight = 58.0 * widget.scale;

    final targetIndex = current < 0 ? 0 : current;
    if (targetIndex != _lastCenteredIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLine(targetIndex, baseLineHeight);
      });
    }

    final Color activeColor = switch (widget.colorMode) {
      EditorialLyricsColorMode.accentColor => palette.accent,
      EditorialLyricsColorMode.mutedColor => palette.inkMuted,
      EditorialLyricsColorMode.pureWhite =>
        isDark ? Colors.white : const Color(0xFF161412),
      EditorialLyricsColorMode.defaultColor => palette.ink,
    };

    final Color inactiveColor = switch (widget.colorMode) {
      EditorialLyricsColorMode.accentColor => palette.accent.withValues(
        alpha: 0.42,
      ),
      EditorialLyricsColorMode.mutedColor => palette.hairlineStrong,
      EditorialLyricsColorMode.pureWhite =>
        isDark ? const Color(0x66FFFFFF) : const Color(0x66161412),
      EditorialLyricsColorMode.defaultColor => palette.inkMuted,
    };

    final Color underlineColor =
        widget.colorMode == EditorialLyricsColorMode.accentColor
        ? palette.accent
        : (widget.colorMode == EditorialLyricsColorMode.mutedColor
              ? palette.inkMuted
              : palette.accent);

    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = (constraints.maxHeight / 2) - (baseLineHeight / 2);

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.12, 0.88, 1.0],
          ).createShader(bounds),
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: pad < 0 ? 0 : pad),
            itemExtent: baseLineHeight,
            itemCount: lines.length,
            itemBuilder: (context, index) {
              final active = index == current;
              final line = lines[index];

              final fontSize = active
                  ? 28.0 * widget.scale
                  : 20.0 * widget.scale;

              TextStyle style;
              if (widget.isSerif) {
                style = GoogleFonts.spectral(
                  fontSize: fontSize,
                  height: 1.18,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? activeColor : inactiveColor,
                );
              } else {
                style = TextStyle(
                  fontSize: fontSize,
                  height: 1.18,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? activeColor : inactiveColor,
                  fontFamilyFallback: const ['Georgia', 'serif'],
                );
              }

              final content = Align(
                alignment: widget.isFullWidth
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: widget.isFullWidth
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: widget.isFullWidth
                          ? TextAlign.center
                          : TextAlign.left,
                      style: style,
                    ),
                    if (active) ...[
                      const SizedBox(height: 3),
                      Container(
                        height: 2,
                        width: (line.text.length * 9.0 * widget.scale).clamp(
                          24.0,
                          260.0,
                        ),
                        color: underlineColor,
                      ),
                    ],
                  ],
                ),
              );

              if (!widget.document.synced) return content;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    unawaited(
                      ref
                          .read(playbackControllerProvider.notifier)
                          .seekTo(line.start),
                    );
                  },
                  child: SizedBox(height: baseLineHeight, child: content),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LyricsPlaceholder extends StatelessWidget {
  const _LyricsPlaceholder({required this.message, required this.palette});

  final String message;
  final StudioPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: palette.inkMuted,
          fontFamilyFallback: const ['Georgia', 'serif'],
        ),
      ),
    );
  }
}
