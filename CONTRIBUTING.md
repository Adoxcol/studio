# Contributing to Studio

Studio is solo-maintained but run like a team project — see [AGENTS.md](./AGENTS.md) for the
full conventions (branching, commits, PRs, releases, code style, testing). This file is the
short version for anyone opening a PR.

## Quick start

```bash
git clone https://github.com/Adoxcol/studio.git
cd studio
git config core.hooksPath .githooks
flutter pub get
flutter run -d macos   # or linux / windows
```

A fresh clone needs `git config core.hooksPath .githooks` once — Git does not clone that
setting, and Conventional-Commit / no-push-to-main checks live in `.githooks/`.

Linux desktop builds also need:

```bash
sudo apt-get install -y ninja-build libgtk-3-dev cmake clang pkg-config libmpv-dev \
  libkeybinder-3.0-dev libayatana-appindicator3-dev
```

## Making a change

1. Branch off the latest `main`: `git checkout -b feat/your-thing`.
2. Make the change, with tests.
3. `dart format .`, `flutter analyze`, `flutter test` — all clean.
4. Add an entry under `Unreleased` in `CHANGELOG.md`.
5. Push and open a PR using the template. Fill it in properly, even solo.
6. Wait for CI to go green, re-read your own diff, then squash-merge.

## Reporting bugs / requesting features

Use the issue templates under `.github/ISSUE_TEMPLATE/`.

## Code of conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).
