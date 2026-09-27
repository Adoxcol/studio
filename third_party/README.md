# Vendored packages

Each package here is pinned through `dependency_overrides` in `pubspec.yaml` because Studio
needs a fix the published version does not have. Drop a copy once upstream ships the fix.

| Package | Based on | Why it is vendored | Drop when |
| --- | --- | --- | --- |
| `docking` | 1.16.2 | Tab-strip context menus, stable drag feedback, in-place reorder, TickerMode for maximized panes. See `docking/STUDIO_PATCHES.md`. | Upstream accepts the patches (latest is still 1.16.2). |
| `tabbed_view` | 1.18.1 | Animated reorder, stable tab identity, primary-button-only drags, TickerMode for inactive content. See `tabbed_view/STUDIO_PATCHES.md`. | Studio moves to a release with equivalent behavior. Upstream 2.x/3.x is a breaking rewrite, and `docking` 1.16.2 still requires `>=1.18.0 <1.19.0`. |
| `discord_rich_presence` | 1.1.1 | `WindowsTransport.close()` throws before closing a dead pipe, leaking the handle. | A release after 1.1.1 fixes `close()` (1.1.1 is still the latest). |
| `media_kit_libs_windows_video` | 1.0.11 | Swaps the 2023 mpv core for media-kit's `20241021` build so the ten-band lavfi equalizer and `aresample` work. See `media_kit_libs_windows_video/README.md`. | A published release bundles an mpv core from `20241021` or later (1.0.11 is still the latest). |
| `native_toolchain_rust` | 1.0.4 | `DependencyDiscoverer` splits Cargo dep-info on every space, which breaks on paths containing escaped spaces (for example Windows user folders). The patch parses from the first `: ` and splits only on unescaped spaces. Pulled in by `velopack_flutter`. | Upstream parses escaped spaces. Still unfixed in 1.0.7, whose other fixes (1.0.5–1.0.7) are not in this copy. |

Last checked against pub.dev: 2026-09-27.

## Checking for updates

```bash
for p in docking tabbed_view discord_rich_presence media_kit_libs_windows_video native_toolchain_rust; do
  printf '%s ' "$p"; curl -s "https://pub.dev/api/packages/$p" | python3 -c 'import sys,json; print(json.load(sys.stdin)["latest"]["version"])'
done
```

When a newer version appears, read its changelog for the fix, delete the copy and its
`dependency_overrides` entry, run `flutter pub get`, and run the full test suite. For
`docking`/`tabbed_view`, also run `test/ui/workspace_interactions_test.dart`.
