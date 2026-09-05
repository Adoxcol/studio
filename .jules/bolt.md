## 2026-08-30 - [Optimization] Added O(1) map for tracking Library Tracks
**Learning:** The application was constantly regenerating the track hash map in `NowPlayingPage` and `QueuePage` by looping over tens of thousands of tracks from `libraryTracksProvider`. By adding `libraryTracksByIdProvider`, we get O(1) lookup on widget rebuilds with zero overhead.
**Action:** Moving O(N) inline list/map processing to a Riverpod Provider to take advantage of caching on rebuilds.

## 2024-05-18 - [Optimization] Avoid O(N) traversals on Track arrays
**Learning:** The 'studio' codebase contains tens of thousands of tracks in `libraryTracksProvider`. Doing `library.where((t) => t.id == selectedId).firstOrNull` creates O(N) overhead during UI rebuilds or metadata syncs.
**Action:** Use the pre-computed `libraryTracksByIdProvider` for O(1) map lookups when retrieving specific tracks by ID. Do not replace O(N) linear searches on small constant enums with map creation via `.asNameMap()` as it creates unnecessary garbage and overhead.
## 2024-05-24 - N+1 Query Optimization in Folder Scanner
**Learning:** In Dart/Drift DB access, iteratively looping and querying relations (like folders and their tracks) can introduce massive N+1 delays. Fetching all items and batching/grouping them in-memory is significantly faster (~90% improvement on 500 folders).
**Action:** When a function accepts a single ID to fetch from the DB and is called iteratively, check if the data can be batched-loaded upstream and passed in as an optional parameter to avoid N+1 querying.
## 2024-05-24 - Avoiding O(N log N) Computation in Widget Getters
**Learning:** In Flutter, it is important not to put O(N log N) processing (like looping over tens of thousands of tracks and sorting the results) inside getter methods of widgets that might rebuild frequently (e.g., from `setState` interacting with UI elements like dropdowns). In `_LibraryFilterDialogState`, doing this recalculates everything on every state change unnecessarily.
**Action:** When a property depends on a static input (like `widget.tracks`) but requires heavy processing, initialize it once (e.g., using `late final`) rather than inside a getter.
## 2024-05-24 - Avoiding unmemoized list traversal inside widget getters
**Learning:** In Flutter, it is important not to put expensive O(N log N) processing (like sorting or filtering all tracks) directly inside `build` method getters without some form of caching. For instance, the smart playlist editor recalculates `matches = definition.evaluate(...)` frequently.
**Action:** When a method processes tens of thousands of items, add memoization inside the Stateful widget instance variables to ensure the values are cached and reused on subsequent builds if inputs are unchanged.
