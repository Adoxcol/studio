## $(date +%Y-%m-%d) - Added accessibility tooltips to playback controls
**Learning:** Found multiple icon-only buttons in `_ImmersiveTransport` missing tooltips, which hurts accessibility and screen readers. Flutter's `IconButton` `tooltip` property handles both visual tooltips on hover and semantic labels for screen readers.
**Action:** When adding icon buttons, verify tooltips are always populated.
