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
  directories. `subosito/flutter-action` installs the project's stable Flutter
  SDK; workflows do not run `sudo` or provision the machine.
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
