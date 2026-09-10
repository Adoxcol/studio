# CI and release runners

Studio's registered self-hosted runner is `homelab-ci-201` (Linux x64), selected
with all four labels: `self-hosted`, `Linux`, `X64`, `homelab`.

| Job | Runner |
| --- | --- |
| CI analysis/tests for main and same-repository PRs | Homelab Linux x64 |
| CI analysis/tests for fork PRs or Dependabot PR runs | GitHub-hosted Ubuntu |
| CI Windows / macOS desktop builds | GitHub-hosted Windows / macOS |
| Release Windows build and packaging | GitHub-hosted Windows |
| Publishing the Windows release artifact | Homelab Linux x64 |

Flutter desktop builds need the corresponding operating system; the Linux
runner cannot replace Windows or macOS hosts. To migrate those build jobs too,
register suitable Windows and macOS runners first. Job names and the desktop
matrix remain unchanged so required checks keep working.

## Public-repository safety

Before enabling this routing, configure **Settings > Actions > General > Fork
pull request workflows** to require approval for **all outside collaborators**.
The REST setting is `approval_policy: all_external_contributors`.

The routing expression is not a security boundary: a fork can edit workflow
YAML. Before approving any external run, review its workflow changes and the
code it would execute. Never approve an external change that redirects work to
the homelab, or use `pull_request_target` to build untrusted PR code.

Use a dedicated, isolated runner with no personal credentials, unrelated
secrets, privileged Docker socket, or access to sensitive homelab services.
Prefer a fresh ephemeral machine for each job. A persistent runner can retain
changes outside the checkout; checkout cleanup and read-only tokens do not
make untrusted code safe. GitHub cautions against self-hosted runners for public
repositories: [self-hosted runner security](https://docs.github.com/en/actions/reference/security/secure-use#hardening-for-self-hosted-runners).

CI and build jobs use read-only repository permissions and do not persist
checkout credentials. Only release publishing receives `contents: write`,
does not check out or execute application code, and downloads its artifact to a
run/attempt-specific temporary directory. Do not keep long-lived credentials
on the host shared by testing and publishing.

## Host prerequisites and operation

- Keep the runner service online and up to date with the labels above.
- Install Git, Bash, curl, unzip, xz/tar, and the standard Linux runtime
  dependencies required by Flutter and the runner's Node-based actions.
- Give the runner user write access to its work, temporary, and tool-cache
  directories, `/opt/ci/cache/flutter`, and `/opt/ci/cache/pub`. Workflows do not
  run `sudo` or provision the machine.
- Allow outbound access to GitHub Actions/artifacts, Flutter downloads,
  pub.dev, and Codecov. Coverage upload remains non-blocking.
- CI cancels superseded runs per PR/ref. CI and release jobs have execution
  timeouts; an offline/mislabelled runner can still leave a job queued, so check
  runner status if work does not start. There is no automatic hosted fallback
  for a trusted self-hosted job.
- Do not run two runner services against the same work directory.

Validate changes with `actionlint`, the normal Flutter checks, and a trusted PR
run. Verify the `analyze_and_test` job's runner name is `homelab-ci-201`.
Release publishing is only exercised by a real release tag; do not create a
release merely to test runner selection.

## Persistent Flutter cache

Both workflows pin Flutter to `3.47.2`, the stable version verified by CI before
the migration. Update both `FLUTTER_VERSION` declarations together when upgrading.
Hosted runners still use `subosito/flutter-action`; the Linux homelab uses
`.github/scripts/setup-flutter-cache.sh`.

- SDK: `/opt/ci/cache/flutter/stable-3.47.2-x64/flutter`.
- Pub packages: `/opt/ci/cache/pub`.
- Interrupted downloads: `/opt/ci/cache/flutter/downloads/*.part`.
- These paths are outside `_work`, so the homelab's weekly workspace purge does
  not remove them. Do not add them to general workspace cleanup.
- A cold download resumes from the partial archive and must match the SHA-256
  checksum in Flutter's official release manifest before extraction. Installation
  is staged and published atomically. A failed download is kept for retry.
- An already installed, verified SDK skips the network download. This is a local
  disk cache, not an upload/download through GitHub Actions cache storage.
- The initial setup may take up to 150 minutes on this connection. Analysis and
  tests retain separate shorter timeouts. Normal runner slot/temperature hooks
  still wrap the job; no extra background downloader bypasses these controls.
- Old SDK versions are retained intentionally. When upgrading, inspect disk usage
  and manually remove only confirmed unused version directories after CI passes.
  Never delete an SDK or package cache while a job is using it.
- The cache belongs to `github-runner`; fork jobs must remain on isolated hosted
  runners. The checksum authenticates the initial download, not later changes by
  code executed on this persistent host.

The runner service hook paths must end in `.sh` (the scripts are Bash). The
installed `.sh` aliases preserve the original scripts. `KillMode=control-group`
ensures a service restart does not leave old Listener processes running. Original
service configurations are backed up as `github-runner.service.studio-hook-fix.bak`
alongside both `/etc/systemd/system` and `/opt/ci/systemd` service files.
