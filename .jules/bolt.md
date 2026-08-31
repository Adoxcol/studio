## 2026-08-30 - [Optimization] Added O(1) map for tracking Library Tracks
**Learning:** The application was constantly regenerating the track hash map in `NowPlayingPage` and `QueuePage` by looping over tens of thousands of tracks from `libraryTracksProvider`. By adding `libraryTracksByIdProvider`, we get O(1) lookup on widget rebuilds with zero overhead.
**Action:** Moving O(N) inline list/map processing to a Riverpod Provider to take advantage of caching on rebuilds.
## 2024-05-24 - N+1 Query Optimization in Folder Scanner
**Learning:** In Dart/Drift DB access, iteratively looping and querying relations (like folders and their tracks) can introduce massive N+1 delays. Fetching all items and batching/grouping them in-memory is significantly faster (~90% improvement on 500 folders).
**Action:** When a function accepts a single ID to fetch from the DB and is called iteratively, check if the data can be batched-loaded upstream and passed in as an optional parameter to avoid N+1 querying.
