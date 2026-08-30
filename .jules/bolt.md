## 2026-08-30 - [Optimization] Added O(1) map for tracking Library Tracks
**Learning:** The application was constantly regenerating the track hash map in `NowPlayingPage` and `QueuePage` by looping over tens of thousands of tracks from `libraryTracksProvider`. By adding `libraryTracksByIdProvider`, we get O(1) lookup on widget rebuilds with zero overhead.
**Action:** Moving O(N) inline list/map processing to a Riverpod Provider to take advantage of caching on rebuilds.
