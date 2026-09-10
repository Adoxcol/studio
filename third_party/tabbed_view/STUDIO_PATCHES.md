# Studio tabbed_view patches

Based on tabbed_view 1.18.1, https://github.com/caduandrade/tabbed_view.
The upstream LICENSE is retained. Only runtime source and package metadata are
vendored; Dart formatting is normalized by the project's format check.

- Expose `tabsAreaBuilder` to wrap the entire strip without intercepting content.
- Preserve tab element identity by the tab's non-null value (DockingItem), even
  when docking rebuilds its TabData/controller instances.
- Animate reordered offsets for 180 ms with ease-out, including hit-test and
  semantics positions; update painting without relaying out panel content.
  Retarget from the current position and disable movement for reduced motion.
- Only primary-button presses initiate drags, leaving right-click for menus.
- Fade the source tab while dragging.
- Keep insertion-target wrappers stable and fade the accent marker from actual
  drag candidates, including cross-strip drags and cancellations.
- Disable TickerMode on inactive content, allowing Studio to defer unopened
  panels and pause hidden animations/provider subscriptions without losing state.

Integration coverage lives in Studio's
`test/ui/workspace_interactions_test.dart`.
