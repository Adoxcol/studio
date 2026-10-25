1. **Explore `lib/theming/appearance_store.dart`**
   - Identify synchronous file reads (`file.readAsStringSync()`).
2. **Implement Async Preloading**
   - Change synchronous reads to asynchronous loading in `AppearanceStore` and cache them in memory.
   - For `FileAppearanceStore`: add a method `loadAsync` which asynchronously reads and caches the JSON, and changes `load` to return the cached value.
3. **Update Main**
   - Wait for `appearance.loadAsync()` inside `main.dart` when setting up `AppearanceStore`.
4. **Pre commit step**
   - Run tests and verifications using `pre_commit_instructions`.
5. **Submit**
   - Provide a PR description following Bolt's specific structure.
