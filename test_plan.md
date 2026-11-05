1. **Explore `lib/ui/now_playing/editorial_player_bar.dart` and `lib/ui/now_playing/editorial_lyrics.dart`**
   - Read the relevant lines and confirm `InkWell` widgets inside `Semantics` lack a `Material(type: MaterialType.transparency)` wrapper.
2. **Update `lib/ui/now_playing/editorial_player_bar.dart`**
   - Wrap the `InkWell` inside `Tooltip` -> `Semantics` (the Audio Engine Settings DSP Badge) in a `Material(type: MaterialType.transparency)` using `replace_with_git_merge_diff`.
3. **Update `lib/ui/now_playing/editorial_lyrics.dart`**
   - Wrap the three font setting `InkWell`s (Toggle font style, Decrease font size, Increase font size) in a `Material(type: MaterialType.transparency)` using `replace_with_git_merge_diff`.
4. **Update `lib/ui/now_playing/editorial_stage_details.dart`**
   - Wrap the `InkWell` inside `Tooltip` -> `Semantics` (Audio Engine Settings) in a `Material(type: MaterialType.transparency)` using `replace_with_git_merge_diff`.
5. **Verify changes**
   - Run `flutter test` to make sure tests pass.
6. **Pre-commit checks**
   - Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.
7. **Submit PR**
   - Submit the PR with the UX format as `Palette` agent.
