## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
