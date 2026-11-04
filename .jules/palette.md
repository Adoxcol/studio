## 2024-11-04 - Native Visual Feedback for Interactive Icons
**Learning:** In Flutter, wrapping interactive icons (like `InkWell`) with `Semantics` and `Tooltip` is great for accessibility and context, but without a `Material(type: MaterialType.transparency)` parent, these icons lack the native material visual feedback (like ripple effects) upon interaction.
**Action:** When creating custom interactive icons using `InkWell`, ensure they are nested inside a `Material(type: MaterialType.transparency)` to provide native visual feedback and improve the overall tactile feel of the UI.
