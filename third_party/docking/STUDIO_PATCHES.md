# Studio docking patches

Based on docking 1.16.2, https://github.com/caduandrade/docking_flutter.
The upstream LICENSE is retained. Only runtime source and package metadata are
vendored; Dart formatting is normalized by the project's format check.

- Expose `tabsAreaBuilder` for tab-strip-only context menus, including empty space.
- Keep drop feedback wrappers mounted during drag start/end, preserving draggable
  state and tab-strip animation rather than replacing the widget subtree.
- Reorder within a tab group in place, retaining the layout/strip identity and
  selected item; correctly adjust insertion indices in both directions.
- Anchor themed drag feedback at the pointer's original grab point; clear drag
  mode on cancellation as well as successful drop.
- Animate split-target bounds/opacity and drag-preview entry. Respect reduced
  motion. Never animate the pointer position or delay a layout commit.
- Disable TickerMode for panes hidden by maximization, pausing animations and
  Riverpod UI subscriptions while preserving their state.

The companion tabbed_view patch animates reorder offsets. Integration coverage
lives in Studio's `test/ui/workspace_interactions_test.dart`.
