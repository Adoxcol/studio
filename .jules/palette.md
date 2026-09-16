## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-05-17 - Semantics for Color Swatches
**Learning:** Custom interactive elements like color swatches (`GestureDetector`) inside `Tooltip` do not inherently provide button semantics to screen readers.
**Action:** Always wrap custom interactive UI elements with a `Semantics` widget (e.g., `button: true`, `label`, `selected`) to ensure they are accessible.
