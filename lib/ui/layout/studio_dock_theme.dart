import 'package:docking/docking.dart';
import 'package:flutter/material.dart';
import 'package:studio/theming/studio_palette.dart';

/// Editorial Mono chrome for [Docking]: hairline splitters, flat tabs, no cards.
class StudioDockChrome extends StatelessWidget {
  const StudioDockChrome({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = StudioPalette.of(context);
    final label = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: palette.inkMuted,
      fontSize: 12,
      letterSpacing: 0.2,
    );
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 6,
        dividerPainter: DividerPainters.background(
          animationEnabled: !MediaQuery.disableAnimationsOf(context),
          color: palette.hairline,
          highlightedColor: palette.hairlineStrong,
        ),
      ),
      child: TabbedViewTheme(data: _tabs(palette, label), child: child),
    );
  }

  static TabbedViewThemeData _tabs(StudioPalette palette, TextStyle? label) {
    final hairline = BorderSide(color: palette.hairline, width: 1);
    return TabbedViewThemeData(
      tabsArea: TabsAreaThemeData(
        color: palette.bg,
        border: Border(bottom: hairline),
        equalHeights: EqualHeights.all,
        dropColor: palette.accent,
        normalButtonColor: palette.inkMuted,
        hoverButtonColor: palette.ink,
        disabledButtonColor: palette.hairlineStrong,
        buttonPadding: const EdgeInsets.all(4),
      ),
      tab: TabThemeData(
        textStyle: label ?? const TextStyle(fontSize: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        paddingWithoutButton: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: palette.bg),
        draggingDecoration: BoxDecoration(color: palette.bg),
        normalButtonColor: palette.inkMuted,
        hoverButtonColor: palette.ink,
        disabledButtonColor: palette.hairlineStrong,
        buttonPadding: const EdgeInsets.all(2),
        highlightedStatus: TabStatusThemeData(
          fontColor: palette.ink,
          decoration: BoxDecoration(color: palette.bg),
        ),
        selectedStatus: TabStatusThemeData(
          fontColor: palette.ink,
          decoration: BoxDecoration(color: palette.bg),
          innerBottomBorder: BorderSide(color: palette.accent, width: 1),
        ),
      ),
      contentArea: ContentAreaThemeData(
        decoration: BoxDecoration(color: palette.bg),
        decorationNoTabsArea: BoxDecoration(color: palette.bg),
      ),
      menu: TabbedViewMenuThemeData(
        color: palette.bg,
        textStyle: label ?? const TextStyle(fontSize: 12),
        hoverColor: palette.hairlineSoft,
        dividerColor: palette.hairline,
        dividerThickness: 1,
        border: Border.all(color: palette.hairline),
        menuItemPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
    )..materialDesignIcons();
  }
}
