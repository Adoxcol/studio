# Studio

> A fast, responsive, highly customizable desktop music player.  
> Local library first — Spotify-style streaming is planned for a later phase.

[![CI](https://github.com/YOUR_USERNAME/studio/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_USERNAME/studio/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/YOUR_USERNAME/studio?label=release)](https://github.com/YOUR_USERNAME/studio/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-blue)](#install)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-54C5F8?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/github/license/YOUR_USERNAME/studio)](LICENSE)

![Dark mode overview](docs/screenshots/darkmode.png)

---

## Features

### Library

- Folder-based scan with incremental re-scan on launch
- Artist / Album / Track / Folder / Playlist tabs with search, sort, and filters
- Filter by lossless format, sample rate, bitrate, genre, year, and source folder
- Multi-select for bulk tag edits with per-track progress reporting
- Floating back button preserves catalogue scroll position, search, and sort

![Library](docs/screenshots/library.png)

---

### Playback

- URI-only playback via **media_kit** (libmpv) — every format libmpv supports
- Dual-player crossfade (0–15 s) with equal-power overlap
- ReplayGain Off / Track / Album
- Queue with history, reorder, batch removal, and Undo
- Shuffle (current track stays first, rest randomized) and Repeat

![Queue](docs/screenshots/queue.png)

---

### Equalizer

- ISO 10-band graphic equalizer (31 Hz – 16 kHz)
- Named presets: Bass, Rock, Pop, Dance, and more
- Import from Equalizer APO GraphicEQ, AutoEQ parametric filter lines, or a 10-gain JSON dump
- Runs as a persistent libmpv audio graph with automatic headroom — no track restart needed

![Equalizer](docs/screenshots/equalizer.png)

---

### Now Playing & Playback Mode

- 32-band FFT spectrum visualizer tapped from a silent PCM stream
- Full-screen **Playback Mode**: artwork, artist image, or Studio-gradient backdrop  
  — responsive for narrow, ultrawide, and low-height windows
- Time-synced lyrics with click-to-seek
- Individually clickable artist credits that open their library catalogue

![Now Playing](docs/screenshots/now-playing.png)

![Playback Mode](docs/screenshots/playback-mode.png)

---

### Playlists

- Regular playlists with drag-to-reorder editor and Save/Cancel
- **Smart playlists** — all/any rules for artist, album, genre, year, format,  
  bitrate, sample rate, and lossless flag; live preview; save library search as a smart playlist
- Rename, duplicate, and confirmed deletion without removing tracks

![Smart Playlists](docs/screenshots/smart-playlist.png)

---

### Metadata editor

- Preview changes before writing — title, artist, album, genre, year, track number
- Replace or remove embedded cover art (JPEG/PNG); cached for immediate use
- Bulk apply shared fields across selected tracks

![Metadata Editor](docs/screenshots/metadata-editor.png)

---

### Appearance & customization

- Dark / Light / System theme
- Auto accent colour derived from album art (OKLCH) or a custom hue wheel
- Dockable workspace — drag, split, resize, or maximize any panel
- Right-click any tab strip to add, move, or hide widgets

![Settings](docs/screenshots/settings.png)

---

### System integration

- Custom frameless titlebar with minimize / maximize / close
- System tray with Play/Pause/Next/Previous; close-to-tray with "don't ask again"
- Global media keys and configurable hotkeys
- Discord Rich Presence with custom templates and artwork upload
- Single-instance: second launch focuses the running window
- Session restore — queue, playhead, and current track survive quit

---

## Install

**Windows (x64)**

1. Download `studio-windows-x64.zip` from the [latest release](https://github.com/YOUR_USERNAME/studio/releases/latest).
2. Unzip anywhere.
3. Run `studio.exe`. Keep the `data` folder and DLLs next to the exe.  
   Windows may show an unsigned-app warning — click **More info → Run anyway**.

**macOS**

1. Download `studio-macos.zip` from the [latest release](https://github.com/YOUR_USERNAME/studio/releases/latest).
2. Unzip and move `studio.app` to your Applications folder.
3. First launch: right-click → **Open** to bypass Gatekeeper (unsigned build).

**Linux (x64)**

1. Download `studio-linux-x64.tar.gz` from the [latest release](https://github.com/YOUR_USERNAME/studio/releases/latest).
2. Extract: `tar -xzf studio-linux-x64.tar.gz`
3. Run `./studio`. Requires `libkeybinder-3.0` and `libayatana-appindicator3` on the host:
   ```bash
   sudo apt install libkeybinder-3.0-dev libayatana-appindicator3-dev
   ```

---

## Build from source

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, 3.x)
- Desktop support enabled for your target platform

**Linux only — extra system packages:**

```bash
sudo apt install libkeybinder-3.0-dev libayatana-appindicator3-dev \
  libgtk-3-dev libblkid-dev liblzma-dev ninja-build cmake pkg-config
```

### Run

```bash
git clone https://github.com/YOUR_USERNAME/studio.git
cd studio
flutter pub get
flutter run -d windows   # or -d macos / -d linux
```

### Release build

```bash
flutter build windows --release   # build\windows\x64\runner\Release\
flutter build macos   --release   # build\macos\Build\Products\Release\
flutter build linux   --release   # build\linux\x64\release\bundle\
```

---

## Tech stack

| Layer | Library |
|-------|---------|
| UI framework | Flutter (Windows · macOS · Linux) |
| State management | Riverpod |
| Database | drift + sqlite3 |
| Audio engine | media_kit (libmpv) |
| Dynamic colour | palette_generator + material_color_utilities |
| Panel layout | docking |
| Window chrome | window_manager |
| Tray + hotkeys | tray_manager · hotkey_manager |
| Fonts | google_fonts (Editorial Mono aesthetic) |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). After cloning, install the git hooks:

```bash
git config core.hooksPath .githooks
```

This project follows [Conventional Commits](https://www.conventionalcommits.org/),
uses a protected `main` branch, and requires CI green before merge.  
Read [AGENTS.md](AGENTS.md) for the full workflow — it applies to human and AI contributors alike.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a full version history.

---

## License

[MIT](LICENSE) — © YOUR_NAME
