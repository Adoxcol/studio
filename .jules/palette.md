## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-05-18 - Semantic Custom Tabs
**Learning:** Custom UI components implemented with `GestureDetector` instead of `InkWell` or material buttons are completely opaque to screen readers unless explicitly wrapped in `Semantics`. It is easy to assume that Flutter applies default semantics for text, but its interactive nature must be communicated using the `button: true` property along with interactive state like `selected`.
**Action:** Always verify custom tab or navigation elements using `GestureDetector` are wrapped in `Semantics` providing role and state.
## 2025-02-13 - Add `Semantics` wrapper to icon rail buttons
**Learning:** `Tooltip` widgets provide a semantic label by default in Flutter, but wrapping custom interactive widgets (like `InkWell` or `GestureDetector`) inside an explicit `Semantics` widget makes it explicitly announce as a toggle button (`button: true`) and communicates selection states (`selected: true`), providing much better context for screen reader users on custom navigation menus.
**Action:** When creating custom toggle buttons or navigation rails using generic touch handlers, always wrap them with `Semantics(button: true, selected: ...)` even if a Tooltip is present, to ensure the role and state are properly announced.
