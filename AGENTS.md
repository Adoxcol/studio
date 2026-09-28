# AGENTS.md — Studio project conventions

Read this before making any change. It applies to every contributor, human or AI agent.

## Project

Studio is a fast, responsive, highly customizable desktop music player. Local library first,
with remote streaming from OpenSubsonic / Navidrome servers kept strictly separate from the
local catalogue. Solo-maintained and open source, run with production-grade process: protected `main`, feature branches, PRs, CI, SemVer.

## Tech stack

- Flutter (desktop targets: macOS, Windows, Linux)
- Riverpod for state management
- drift + sqlite3 for the local library database
- media_kit (libmpv-backed) for audio playback
- material_color_utilities for dynamic color from album art
- docking for the dockable panel layout
- window_manager for the custom titlebar
- tray_manager / hotkey_manager for system tray + global hotkeys

## Non-negotiable git workflow

- `main` is protected. No direct commits or pushes to `main` — not even by the maintainer.
  Every change lands through a pull request.
- Branch naming: `feat/<slug>`, `fix/<slug>`, `chore/<slug>`, `docs/<slug>`, `refactor/<slug>`,
  `perf/<slug>`, `test/<slug>`, `release/<version>`.
- One logical change per branch/PR. Keep PRs small enough to actually review.
- Rebase feature branches onto the latest `main` before opening or updating a PR. Never rewrite
  history that has already been pushed to `main`.
- Squash-merge into `main`. The squash commit message is the Conventional Commit for that change.
- Delete the branch after merge.

## Commit messages — Conventional Commits

Format: `<type>(<optional scope>): <summary>`

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
Breaking changes: append `!` after the type/scope, or add a `BREAKING CHANGE:` footer.

Examples:
```
feat(player): add crossfade between tracks
fix(library): correct artist grouping when sort order changes
chore: bootstrap CI and PR templates
```

## Pull requests

- Every PR uses `.github/PULL_REQUEST_TEMPLATE.md` and stays scoped to one concern.
- CI (`.github/workflows/ci.yml`) must be green before merge: format check, analyze, and tests
  run on every PR; the macOS / Windows / Linux desktop build matrix runs on pushes to `main`.
- Self-review is mandatory even solo: re-read the whole diff before merging, as if reviewing
  someone else's code.
- Link the issue with `Closes #N` when one exists.

## Releases and versioning

- Semantic Versioning (`MAJOR.MINOR.PATCH`) tracked in `pubspec.yaml`.
- A release PR moves `CHANGELOG.md`'s `Unreleased` section into a new dated version heading.
- After merging a release PR, tag `main` as `vX.Y.Z`. Pushing that tag triggers
  `.github/workflows/release.yml`, which publishes a GitHub Release whose notes are that
  version's `CHANGELOG.md` section (the job fails if it is missing) plus the list of merged PRs.

## Code style

- `dart format .` must produce zero diff — enforced in CI.
- `flutter analyze` must produce zero warnings, using the lint set in `analysis_options.yaml`.
- Folder layout follows `.cursor/.rules/architecture.mdc`. Core subsystems keep their top-level
  folders (`lib/playback`, `lib/library`, `lib/lyrics`, `lib/providers`, `lib/theming`,
  `lib/discord`, `lib/ui`); self-contained features go in
  `lib/features/<feature>/{data,domain,presentation}`; small shared helpers go in `lib/core/`.
- `lib/state/` holds only app-wide providers that tie core subsystems together. Providers for a
  single feature live with that feature — `lib/state/` is not a dumping ground.

## Testing

- Unit tests for anything in `domain`/`data` (repositories, tag parsing, audio-engine wrappers).
- Widget tests for interactive UI; golden tests for design-system components once a theme is
  locked in.
- New logic doesn't merge without tests. Bug fixes get a regression test.

## Rules specifically for AI coding agents (Cursor, Claude, Copilot, etc.) working in this repo

- Never commit or push directly to `main`. Always branch first, using the prefixes above.
- Before opening a PR, run locally and fix anything flagged:
  `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`.
- Update `CHANGELOG.md` under `Unreleased` for any user-facing change.
- Never bump the version in `pubspec.yaml` unless explicitly asked to cut a release.
- Never force-push a branch that has an open PR without flagging it first.
- Prefer several small Conventional-Commit commits over one large commit.
- If a task is ambiguous, state the assumption made in the PR description and proceed — don't
  silently guess, and don't block on it either.

## Local setup

```bash
flutter pub get
flutter run -d macos   # or -d linux / -d windows
```
