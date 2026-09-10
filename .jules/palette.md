## 2026-09-10 - Added accessibility tooltips to playback controls
**Learning:** Found multiple icon-only buttons in `_ImmersiveTransport` missing tooltips, which hurts accessibility and screen readers. Flutter's `IconButton` `tooltip` property handles both visual tooltips on hover and semantic labels for screen readers.
**Action:** When adding icon buttons, verify tooltips are always populated.
## 2024-05-18 - Missing Semantics in Custom Clickable Widgets
**Learning:** Custom clickable widgets wrapped in `GestureDetector` lack proper semantics for screen readers, meaning they are not announced as interactive elements or buttons.
**Action:** Wrap custom clickable widgets like `GestureDetector` with `Semantics(button: true, label: ...)` to ensure proper screen reader accessibility.
## 2024-05-18 - Semantic Custom Tabs
**Learning:** Custom UI components implemented with `GestureDetector` instead of `InkWell` or material buttons are completely opaque to screen readers unless explicitly wrapped in `Semantics`. It is easy to assume that Flutter applies default semantics for text, but its interactive nature must be communicated using the `button: true` property along with interactive state like `selected`.
**Action:** Always verify custom tab or navigation elements using `GestureDetector` are wrapped in `Semantics` providing role and state.
## 2025-02-13 - Add `Semantics` wrapper to icon rail buttons
**Learning:** `Tooltip` widgets provide a semantic label by default in Flutter, but wrapping custom interactive widgets (like `InkWell` or `GestureDetector`) inside an explicit `Semantics` widget makes it explicitly announce as a toggle button (`button: true`) and communicates selection states (`selected: true`), providing much better context for screen reader users on custom navigation menus.
**Action:** When creating custom toggle buttons or navigation rails using generic touch handlers, always wrap them with `Semantics(button: true, selected: ...)` even if a Tooltip is present, to ensure the role and state are properly announced.
## 2025-02-13 - Format commands affect third-party directories
**Learning:** Running `dart format .` globally formats all code, including files in `third_party/`, which leads to bloated and undesirable PR diffs.
**Action:** When running formatting tools, ensure any changes applied to third-party dependencies are explicitly reverted (e.g. `git restore --staged third_party/ && git checkout third_party/`) before committing.
## 2025-02-13 - Add Semantics wrapper to Library Browse custom views
**Learning:** In the Library view, custom cards for artists and albums implemented using `GestureDetector` are not inherently accessible as buttons to screen readers. Relying only on text labels inside the cards is insufficient to communicate their interactive role.
**Action:** When building custom grid or list views for visual media (like album art and artist portraits) using `GestureDetector`, always wrap the entire card in a `Semantics` widget with `button: true` and a descriptive label (e.g., 'Album [Name] by [Artist]').
## 2026-09-10 - Add `Semantics` wrapper to custom window controls
**Learning:** Even when custom controls (like window minimize, maximize, and close buttons implemented with `GestureDetector` in a `Tooltip`) have tooltips that provide accessibility labels, they are not inherently announced as buttons by screen readers because they lack the `button: true` semantics.
**Action:** Always wrap custom interactive widgets, even those within a `Tooltip`, with an explicit `Semantics(button: true, label: ...)` widget to ensure screen readers correctly communicate their role and state to users.
