## 2024-05-24 - Use IconButton for interactive icons
**Learning:** Manually wrapping a `GestureDetector` inside a standalone `Tooltip` and `Semantics(button: true)` creates verbose code and can duplicate semantics nodes compared to standard widgets.
**Action:** Use Flutter's native `IconButton` widget instead, which intrinsically provides both visual tooltips and correct semantic button structure for screen readers without manual nesting.
## 2026-10-06 - Interactive List Items
**Learning:** In Flutter applications, custom list items and cards built with `GestureDetector` and `MouseRegion` lack native visual feedback on hover or tap, making them feel less responsive.
**Action:** Replace `GestureDetector` + `MouseRegion` with `InkWell` wrapped in `Material(type: MaterialType.transparency)` and set `hoverColor` to provide smooth, native Material ripple and hover effects.
## 2026-10-06 - Interactive Grid Tile Items
**Learning:** Similar to list items, custom grid tiles (`_GenreTile` in `LibraryBrowseView`) built with `GestureDetector`, `MouseRegion`, and custom `_hovered` state lack native Material visual feedback.
**Action:** Replace `GestureDetector` + `MouseRegion` and custom `setState` hover logic with `InkWell` wrapped in `Material(type: MaterialType.transparency)`. Set `hoverColor` to provide a smooth, native Material ripple and hover effect, which is less verbose and visually superior.
