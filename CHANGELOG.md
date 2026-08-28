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
- Known music folders are re-scanned on launch so new and removed files show
  up without adding the folder again.
- Library folders can be removed from the sidebar. Scan progress appears in a
  side notice with Stop, and a refresh control re-scans on demand.
- Appearance settings: Auto accent from album art or a custom hue swatch,
  both using the same OKLCH chroma/lightness formula.
- Now Playing shows a 32-band FFT spectrum under the cover art, tapped from
  a silent mpv PCM dump so ReplayGain and EQ are reflected.
- Library, Now Playing, and Queue sit in a dockable workspace: drag a panel
  by its header, resize the split, or maximize it. Settings stays a full page.
- ReplayGain Off / Track / Album in Settings, applied through mpv.
- 8-band equalizer with Flat / Warm / Bright / Custom presets, applied
  through mpv firequalizer.
- Dual-player crossfade in Settings (Off / 2s / 5s / 8s). Skip and
  end-of-track overlap with an equal-power fade; the FFT tap follows
  the incoming track.

### Changed

- Folder scans skip unchanged files, read cover art only when needed, stay
  cancellable so the library does not freeze for minutes, and parse tags off
  the UI isolate in batches so large folders stay responsive.
- Library lists use a fixed row height so long All / Queue views stay smooth
  when scrolling far down. Playback position ticks only rebuild the scrubber.
  The spectrum visualizer listens to its own FFT band stream.

### Fixed

- Linux CI installs `libkeybinder-3.0-dev` and `libayatana-appindicator3-dev` so
  `hotkey_manager` and `tray_manager` can build.
- Opening an existing library no longer fails to add `indexed_at` (SQLite
  rejects `ALTER TABLE` with a `CURRENT_TIMESTAMP` default).

### Removed

## [0.1.0] - 2026-08-28

### Added

- Initial project scaffolding.
