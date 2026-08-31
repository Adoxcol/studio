## 2026-08-30 - [Optimization] Added O(1) map for tracking Library Tracks
**Learning:** The application was constantly regenerating the track hash map in `NowPlayingPage` and `QueuePage` by looping over tens of thousands of tracks from `libraryTracksProvider`. By adding `libraryTracksByIdProvider`, we get O(1) lookup on widget rebuilds with zero overhead.
**Action:** Moving O(N) inline list/map processing to a Riverpod Provider to take advantage of caching on rebuilds.

## 2024-05-18 - [Optimization] Avoid O(N) traversals on Track arrays
**Learning:** The 'studio' codebase contains tens of thousands of tracks in `libraryTracksProvider`. Doing `library.where((t) => t.id == selectedId).firstOrNull` creates O(N) overhead during UI rebuilds or metadata syncs.
**Action:** Use the pre-computed `libraryTracksByIdProvider` for O(1) map lookups when retrieving specific tracks by ID. Do not replace O(N) linear searches on small constant enums with map creation via `.asNameMap()` as it creates unnecessary garbage and overhead.
