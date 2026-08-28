# Studio

A fast, customizable desktop music player. Local library first; a Spotify-style
streaming linkup is planned later.

**Stack:** Flutter (Windows, macOS, Linux) · Riverpod · drift/sqlite3 · media_kit ·
window_manager · tray_manager / hotkey_manager.

This is a solo-maintained open source project run with production-grade process.
Read [AGENTS.md](./AGENTS.md) before changing anything.

## Run

```bash
flutter pub get
flutter run -d windows   # or macos / linux
```

## Contribute

See [CONTRIBUTING.md](./CONTRIBUTING.md). After cloning:

```bash
git config core.hooksPath .githooks
```
