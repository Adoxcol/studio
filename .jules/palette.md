## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-05-18 - Semantic Custom Tabs
**Learning:** Custom UI components implemented with `GestureDetector` instead of `InkWell` or material buttons are completely opaque to screen readers unless explicitly wrapped in `Semantics`. It is easy to assume that Flutter applies default semantics for text, but its interactive nature must be communicated using the `button: true` property along with interactive state like `selected`.
**Action:** Always verify custom tab or navigation elements using `GestureDetector` are wrapped in `Semantics` providing role and state.
