## 2024-05-24 - Use IconButton for interactive icons
**Learning:** Manually wrapping a `GestureDetector` inside a standalone `Tooltip` and `Semantics(button: true)` creates verbose code and can duplicate semantics nodes compared to standard widgets.
**Action:** Use Flutter's native `IconButton` widget instead, which intrinsically provides both visual tooltips and correct semantic button structure for screen readers without manual nesting.
