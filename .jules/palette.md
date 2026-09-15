## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-05-19 - Missing Semantics in Custom Clickable Widgets
**Learning:** In Flutter, using `GestureDetector` for custom interactive elements (like icon buttons or color swatches) without adding semantics makes them inaccessible to screen readers.
**Action:** Wrap such custom interactive elements with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
