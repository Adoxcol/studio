## 2024-06-25 - Avoid Synchronous File I/O for Playback Session Loading
**Learning:** `file.readAsStringSync()` and `file.existsSync()` can block the main UI isolate for over 40ms when parsing large JSON blobs (~50k tracks, >500KB), causing 60Hz/120Hz frame drops (jank) in a Flutter desktop application. Even though asynchronous alternatives (`readAsString()`) might have slightly slower raw execution times because of the overhead of executing on the thread pool or spanning isolate boundaries, their non-blocking nature is essential for maintaining UI responsiveness.
**Action:** When designing a persistence layer (e.g., `PlaybackSessionStore`), design interfaces using `Future<T>` from the start so implementations can safely use asynchronous filesystem methods without propagating refactoring ripples.
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
## 2026-08-30 - Avoiding O(N) list traversal inside widget rebuilds for playlists
**Learning:** In Flutter, it is important not to put O(N) processing (like looping over lists to find items by ID) directly inside `build` methods or frequently rebuilt widgets.
**Action:** When a method needs to lookup an item by ID, add a Riverpod provider to expose an O(1) map of items by ID and use that provider in the widget instead.

## 2026-09-10 - Use Batching for Large ID Collections
**Learning:** `isIn()` queries with thousands of IDs can hit `SQLITE_MAX_VARIABLE_NUMBER` limits and perform very poorly. Drift handles `batch` operations with `.deleteWhere` inside loops significantly faster for large collections without hitting those variable limits.
**Action:** When performing operations on potentially large lists of database IDs, prefer iterating over the IDs inside a `batch()` rather than using `isIn()`.
## 2024-09-09 - Async File System Operations

**Learning:** Using synchronous file operations like `existsSync()` inside async functions blocks the current thread, potentially causing UI stutters or jank.

**Action:** Always prefer asynchronous file I/O operations (e.g., `await file.exists()`) inside `async` methods to keep the event loop unblocked.
## 2024-06-25 - Prevent blocking main thread with sync file operations
**Learning:** Using synchronous I/O methods like `statSync()` or `existsSync()` on the main isolate can block the thread and cause UI jank, even if raw execution time is slightly lower than the async equivalents due to isolate crossing overhead.
**Action:** Always prefer asynchronous file system operations (`stat()`, `exists()`) in Flutter/Dart applications, propagating `async`/`await` up the call stack as necessary, to keep the UI thread responsive.
