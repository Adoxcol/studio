# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Desktop shell with library, settings, and player placeholders.
- Riverpod, drift/sqlite3, media_kit, and window_manager stack declared.
- Editorial Mono frameless shell: custom titlebar, 64px icon rail, and
  divider-scrubber player bar (light theme default).
- Local library folder scan with Drift index, URI-only media_kit playback,
  and a play queue.
- Library browser matching the Editorial Mono All view: collapsible artist
  sidebar, tabs, search, typographic sort/order, and TITLE/ARTIST/ALBUM/TIME
  columns.
- Now Playing hero: Spectral display title, embedded cover art, and a 280px
  Up Next queue panel.

### Changed
### Fixed

- Linux CI installs `libkeybinder-3.0-dev` and `libayatana-appindicator3-dev` so
  `hotkey_manager` and `tray_manager` can build.
- Opening an existing library no longer fails to add `indexed_at` (SQLite
  rejects `ALTER TABLE` with a `CURRENT_TIMESTAMP` default).

### Removed

## [0.1.0] - 2026-08-28

### Added

- Initial project scaffolding.
