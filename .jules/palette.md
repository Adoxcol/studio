## 2024-05-24 - Enhance Volume Control UX
**Learning:** Interactive widgets like a volume icon should inherently be built with `IconButton` rather than using `Icon` wrapped in `MouseRegion`/`GestureDetector` to natively get `Tooltip` support (and by extension ARIA-like semantics for screen readers) and focus states.
**Action:** Consistently replace static icons that are intended to be interactive with `IconButton`, using its `tooltip` property to provide a semantic label and hover text.
