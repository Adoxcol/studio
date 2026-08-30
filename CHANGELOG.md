# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Wikimedia artist portraits now download even with incomplete credit metadata.
  Available credits are retained, missing details are marked as unknown, and old
  misses are retried without replacing saved or custom images.
- Library navigation now uses a Folders tab beside Playlists instead of the
  inner sidebar and Recently Added tab. Folder lists and Add folder controls
  are shared with Settings; opening a folder shows its tracks.
- Window controls now sit on the right with recognizable minimize, maximize,
  and close icons. Queue rows consistently show compact artwork, track title,
  artist credit, and duration across Queue and Up Next.
- The player bar spans the full window below the navigation rail, with transport
  controls anchored to the window's true center at every window size.
- Now Playing no longer duplicates the queue with an Up Next sidebar. The
  queue-backed panel is retained for the future full-screen playback view.

### Added

- Floating library Back button restores the previous artist, album, genre,
  playlist, or folder catalogue with its scroll position, search, and sorting.
  Selecting the original tab also returns to the saved catalogue position.
- TheAudioDB's public free API is an additional artist-portrait source, with
  MusicBrainz-ID matching, free-tier request pacing, source credits, and cached
  images. Previous missing portraits are retried without replacing saved images.
- Optional fanart.tv artist portraits with local project/personal key settings,
  source credits, and Wikimedia fallback. API keys are never bundled or logged.
- Artist-picture console diagnostics show artist names, cache hits, lookup stages,
  HTTP results, skipped-match reasons, downloads, cancellations and retry errors.
- Automatic artist portraits for the whole library using MusicBrainz / Wikimedia,
  with rate-limited background fetching, persistent local caching, image credits,
  manual image overrides and portrait placeholders in Artist and library views.
  Settings can disable online fetching without losing cached or custom pictures.
- Dockable Artist, Album, and Track detail tabs alongside Now Playing, using
  local library metadata. They follow playback or a track chosen through the
  library's View details action without interrupting the music.
- ISO 10-band graphic equalizer (31 Hz–16 kHz) with the usual named
  presets (Bass, Rock, Pop, Dance, and the rest) plus Import for
  Equalizer APO GraphicEQ, parametric Filter lines (AutoEQ / Peace), or
  a 10-gain JSON/text dump. Those curves are mapped onto the 10 ISO
  bands. The curve runs in one persistent libmpv audio graph with automatic
  headroom, while mpv renders directly to the platform's realtime output.
- Discord Rich Presence. Settings → Discord can show the current track
  as Listening while the Discord desktop app is running. Off by default.
  The card lists track, artist, and album; the compact 🎵 line is
  `artist - track`. Cover art is uploaded to catbox.moe so Discord
  can display it. Play/Pause follows playback (Discord buttons are
  links, they cannot control the player). Playing tracks show a
  progress bar.

### Fixed

- Artist lookup retains resolved MusicBrainz identities across retries/restarts.
  Portrait downloads use inactivity timeouts and a bounded overall deadline,
  so a slow but progressing transfer is not cancelled after 15 seconds.
  Temporary service failures respect Retry-After and resume the interrupted
  artist with the queue, instead of imposing a separate one-hour artist delay.
  Changing image sources retries misses without replacing existing pictures.
- Playback with EQ enabled no longer stalls or crackles after pause,
  seek, skip, or rapid slider changes. mpv now owns the realtime audio
  output, and EQ changes update named filters in its persistent graph without
  reopening the track or blocking transport commands. Windows builds pin the
  checksum-verified 2024 media-kit core because the published package's 2023
  mpv cannot address an individual filter inside that graph.
- Discord presence updates skip and play/pause without dropping every
  other track. A dead Windows pipe no longer throws `Write error`
  from close, and presence reconnects on the next update.
- Windows (and macOS) use the Studio tray artwork instead of Flutter's
  default logo.
- Restoring the last session no longer plays a burst of audio before
  pausing.
- Discord cover uploads go to catbox.moe. Presence is sent
  immediately; the cover is filled in when the upload lands.
- The playhead no longer sticks at 0:00 when a track is playing:
  tagged length is used until mpv reports, and a later 0 duration
  does not wipe it.

## [0.1.1] - 2026-08-29

### Added

- Light, Dark, or System theme. Dark uses the Editorial Mono night
  surfaces; System follows the OS. Accents stay the same hue.

## [0.1.0] - 2026-08-29

First public desktop build. GitHub Releases attach a Windows zip (`studio.exe`).

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
- Appearance settings: Auto accent from album art or a custom hue —
  any point on the wheel, with named swatches as shortcuts. Both use
  the same OKLCH chroma/lightness formula.
- Now Playing shows a 32-band FFT spectrum under the cover art, tapped from
  a silent mpv PCM dump so ReplayGain and EQ are reflected.
- Library, Now Playing, and Queue sit in a dockable workspace: drag a panel
  by its header, resize the split, or maximize it. Settings stays a full page.
- ReplayGain Off / Track / Album in Settings, applied through mpv.
- 8-band equalizer with Flat / Warm / Bright / Custom presets, stored in
  settings. media_kit's libmpv cannot apply a graphic EQ (`aresample` and
  `firequalizer` are missing), so sliders do not touch the live decoder.
- Dual-player crossfade in Settings as a 0–15s slider. Skip and
  end-of-track overlap with an equal-power fade; the FFT tap follows
  the incoming track.
- Local playlists: create a list from the Playlists tab, right-click a
  track to add it, then Play All / Shuffle that list.
- System tray with Play / Pause / Next / Previous. Closing the window
  hides to the tray; Quit is on the tray menu. Media keys (play/pause,
  next, previous) work while the window is in the background.
- Queue, current track, and playhead are restored after Quit (paused at
  the same position). Tracks that left the library are dropped.
- A second launch focuses the running window instead of opening another
  copy.
- Click a time-synced lyric to jump playback to that line.
- Closing the window asks Close or Run in background, with Don't show
  again to remember the choice.
- Initial project scaffolding.

### Changed

- Shuffle rearranges the play queue: the current track stays first and the
  rest is randomized. Turning shuffle off restores the original order.
- The library lists each person once. "Drake feat. 21 Savage" stays
  under Drake's albums and also shows up in 21 Savage's catalog.
  Combined names are not their own artists. Track rows still show
  the full credit.
- Library sort includes Track (disc order). Opening an album uses that
  order by default. Sort by Album still lists albums A–Z, but tracks
  inside each album stay in disc order (1, 2, 3).
- The Albums tab groups by artist, with square cover art, title, and
  year under each album. Newer records sit first.
- All / Recently Added tracks use a cover card grid (title, artist,
  album · year). View: List keeps the column table. Settings can hide
  cover thumbnails.
- Missing track covers fill from embedded tags, `cover.jpg` in the
  folder, other tracks on the same album, then iTunes (Settings can
  turn download off).

- Folder scans skip unchanged files, read cover art only when needed, stay
  cancellable so the library does not freeze for minutes, and parse tags off
  the UI isolate in batches so large folders stay responsive.
- Library lists use a fixed row height so long All / Queue views stay smooth
  when scrolling far down. Playback position ticks only rebuild the scrubber.
  The spectrum visualizer listens to its own FFT band stream.
- The player-bar times stay hidden until hover (or while dragging). Then
  start, current position, and end appear above the scrubber.
- Now Playing spectrum stays in the rest pose. The silent second libmpv
  (`ao=pcm`) froze the window, muted the speakers, or killed the process.

### Fixed

- Debug launches no longer die with `NativeReferenceHolder: Located …`
  then `Lost connection to device`. A leftover media_kit handle file from
  a crashed run is discarded before init (Windows reuses PIDs).
- Windows no longer exits as soon as the window appears. `tray_manager`
  called `DestroyIcon` on an uninitialized handle on first `setIcon` in
  Debug, and `hotkey_manager` aborted on a null Next/Previous keyCode.
  The tray icon and media keys now come from the runner. Close hides
  only after that icon exists.
- Playback no longer starts a second libmpv FFT tap. That instance's
  `ao=pcm` `stop`/`open`/`dispose` native-crashed the Windows process.
- Skip next keeps playing after shuffle (and after any skip). The next
  file no longer opens against mpv's disk cache, and a completed event
  from the outgoing file no longer steals the open.
- The equalizer no longer seeks the track or kills audio. media_kit's
  libmpv has no `aresample`/`firequalizer`, so a lavfi graph was flushing
  the decoder on every slider move (`Disabling filter lavfi`). EQ is kept
  in settings only until there is a real DSP path.
- Play, pause, skip, and the progress bar respond on the first click: the
  transport no longer waits on a second player, skip is not dropped
  while a track is still opening, and the scrubber can be clicked or dragged
  without the playhead bouncing back to the old time.
- Pause and resume take effect immediately instead of waiting on media_kit's
  command queue (or an idle crossfade player still opening the next track).
- Now Playing no longer overflows by a few pixels when the pane is short or
  the title wraps.
- The library header no longer overflows in a narrow docked pane.
- Linux CI installs `libkeybinder-3.0-dev` and `libayatana-appindicator3-dev` so
  `hotkey_manager` and `tray_manager` can build.
- Opening an existing library no longer fails to add `indexed_at` (SQLite
  rejects `ALTER TABLE` with a `CURRENT_TIMESTAMP` default).
