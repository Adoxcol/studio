## 2024-05-19 - Semantic Buttons
**Learning:** In Flutter, explicit wrapping of interactive elements (e.g. `GestureDetector`) with `Semantics(button: true, label: ...)` is critical for accurate screen reader announcements in custom list items.
**Action:** When creating custom list rows/cards with `GestureDetector`, apply a `Semantics` wrapper for accessibility.
