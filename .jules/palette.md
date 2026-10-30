## 2024-05-24 - Use IconButton for interactive icons
**Learning:** Manually wrapping a `GestureDetector` inside a standalone `Tooltip` and `Semantics(button: true)` creates verbose code and can duplicate semantics nodes compared to standard widgets.
**Action:** Use Flutter's native `IconButton` widget instead, which intrinsically provides both visual tooltips and correct semantic button structure for screen readers without manual nesting.
## 2026-10-06 - Interactive List Items
**Learning:** In Flutter applications, custom list items and cards built with `GestureDetector` and `MouseRegion` lack native visual feedback on hover or tap, making them feel less responsive.
**Action:** Replace `GestureDetector` + `MouseRegion` with `InkWell` wrapped in `Material(type: MaterialType.transparency)` and set `hoverColor` to provide smooth, native Material ripple and hover effects.
## 2026-10-06 - Interactive Grid Tile Items
**Learning:** Similar to list items, custom grid tiles (`_GenreTile` in `LibraryBrowseView`) built with `GestureDetector`, `MouseRegion`, and custom `_hovered` state lack native Material visual feedback.
**Action:** Replace `GestureDetector` + `MouseRegion` and custom `setState` hover logic with `InkWell` wrapped in `Material(type: MaterialType.transparency)`. Set `hoverColor` to provide a smooth, native Material ripple and hover effect, which is less verbose and visually superior.
## 2026-10-16 - Interactive Custom Segmented Controls
**Learning:** In Flutter applications, custom segmented control tabs (like the `_SegmentedModePill` in the Player Bar) built with `GestureDetector` lack the native Material visual feedback, such as pointer cursors on hover or ink ripples on click.
**Action:** Replace `GestureDetector` with an `InkWell` wrapped in `Material(type: MaterialType.transparency)`. Ensure you provide `borderRadius` and a `hoverColor` matching the existing aesthetic. This gives custom controls native interactive feedback and eliminates the missing pointer cursor issue.
## 2026-10-17 - Interactive Artist/Album Byline
**Learning:** In Flutter applications, text that is clickable but wrapped in a simple `GestureDetector` and `MouseRegion` feels unresponsive as it lacks visual hover and ripple feedback.
**Action:** Use an `InkWell` wrapped in `Material(type: MaterialType.transparency)` and set `hoverColor` (and padding) to provide a native Material interactive experience on text elements.
## 2026-10-18 - Interactive Custom Form Controls
**Learning:** In Flutter applications, custom form controls (like the "Don't show again" checkbox row in `CloseWindowDialog`) built with a simple `GestureDetector` lack native Material visual feedback and do not naturally support keyboard navigation or focus states out of the box.
**Action:** Replace `GestureDetector` with an `InkWell` wrapped in `Material(type: MaterialType.transparency)`. Add a `hoverColor` (e.g., `palette.ink.withValues(alpha: 0.05)`), padding, and `borderRadius`. Ensure inner `Row`s use `mainAxisSize: MainAxisSize.min` so the hover effect tightly wraps the content rather than unnecessarily filling available horizontal space.
## 2024-05-18 - Custom volume sliders lack accessibility support
**Learning:** Custom UI controls built from `GestureDetector` (like volume sliders) are completely invisible to screen readers, making them inaccessible.
**Action:** When building custom sliders in Flutter, explicitly wrap them with a `Semantics` widget including `slider: true`, `value`, `increasedValue`, `decreasedValue`, and `onIncrease`/`onDecrease` callbacks.
## 2024-05-18 - Custom EQ sliders lack accessibility support
**Learning:** Custom UI controls built from `GestureDetector` (like EQ sliders) are completely invisible to screen readers, making them inaccessible.
**Action:** When building custom sliders in Flutter, explicitly wrap them with a `Semantics` widget including `slider: true`, `value`, `increasedValue`, `decreasedValue`, and `onIncrease`/`onDecrease` callbacks.
## 2024-10-28 - Hue Slider Semantics
**Learning:** Custom visual sliders built purely with `GestureDetector` miss out on semantic tree representation, meaning screen readers cannot interact with or understand them.
**Action:** Always wrap custom sliders in a `Semantics` widget with `slider: true`, `value`, `increasedValue`, `decreasedValue`, and appropriate `onIncrease`/`onDecrease` callbacks.
## 2024-05-24 - Interactive color swatches lack keyboard focus
**Learning:** Custom interactive elements built with `GestureDetector` and `MouseRegion` inside a `Semantics` node (like the color `_Swatch` in `settings_appearance.dart`) provide mouse hover and screen reader support, but they lack native keyboard focus support and standard visual ripple feedback, making keyboard navigation difficult.
**Action:** Always wrap custom interactive UI elements in an `InkWell` inside a `Material(type: MaterialType.transparency)` widget instead of using `GestureDetector` directly to ensure native keyboard focus states and visual ripple feedback are natively handled.
