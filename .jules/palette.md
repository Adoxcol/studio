## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-05-17 - Semantics for Color Swatches
**Learning:** Custom interactive elements like color swatches (`GestureDetector`) inside `Tooltip` do not inherently provide button semantics to screen readers.
**Action:** Always wrap custom interactive UI elements with a `Semantics` widget (e.g., `button: true`, `label`, `selected`) to ensure they are accessible.
## 2024-05-19 - Missing Semantics in Custom Clickable Widgets
**Learning:** In Flutter, using `GestureDetector` for custom interactive elements (like icon buttons or color swatches) without adding semantics makes them inaccessible to screen readers.
**Action:** Wrap such custom interactive elements with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-09-19 - Explicit Semantics for Custom Interactive Widgets
**Learning:** Custom interactive widgets (like `GestureDetector`) used to build standard UI controls (like switches, swatches, or toggle buttons) lack implicit accessibility context. Relying solely on a parent `Tooltip` is insufficient as it does not communicate the control's role (e.g., as a button) or its current state (e.g., selected or unselected).
**Action:** When implementing custom interactive elements, always explicitly wrap them in a `Semantics` widget. Define `button: true`, provide a descriptive `label`, and set interactive states like `selected: true/false` so screen readers correctly identify and announce their roles and states to users.
## 2026-09-21 - Explicit Selected State for Custom Interactive Widgets
**Learning:** Custom interactive widgets (like `InkWell` or `GestureDetector`) used to build standard UI controls (like navigation rails) lack implicit accessibility context for their interactive states. Relying solely on a parent `Tooltip` is insufficient as it does not communicate the control's current state (e.g., selected or unselected).
**Action:** When implementing custom interactive elements that have selection states, always explicitly wrap them in a `Semantics` widget. Define `button: true`, provide a descriptive `label`, and importantly set interactive states like `selected: true/false` so screen readers correctly identify and announce their roles and states to users.
## 2026-09-24 - Semantics Wrappers for Custom Clickable Widgets
**Learning:** Custom interactive elements built with  or  in Flutter are not automatically announced as buttons by screen readers unless explicitly marked.
**Action:** Always wrap custom interactive widgets with `Semantics(button: true, label: ...)` to ensure they are accessible and correctly interpreted by assistive technologies.
## 2024-05-24 - Semantics Wrappers for Custom Clickable Widgets
**Learning:** Custom interactive elements built with `GestureDetector` or `InkWell` in Flutter are not automatically announced as buttons by screen readers unless explicitly marked.
**Action:** Always wrap custom interactive widgets with `Semantics(button: true, label: ...)` to ensure they are accessible and correctly interpreted by assistive technologies.
