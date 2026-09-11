# Studio releases

Windows releases use [Velopack](https://velopack.io/) and are published to
GitHub Releases. The Flutter `pubspec.yaml` version remains the development
fallback; production builds receive the exact semantic version from the Git
tag through `STUDIO_VERSION` and Flutter's `--build-name`.

## Production release

1. Update `pubspec.yaml` to the next `MAJOR.MINOR.PATCH` version and update
   `CHANGELOG.md`.
2. Create and push an annotated tag:

   ```powershell
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

3. The release workflow validates the tag, runs format/analyze/tests, builds
   Windows/macOS/Linux, packages Windows with `vpk`, signs and verifies the
   Windows binaries, and publishes the Velopack assets plus the other platform
   archives only after all required steps pass.

Required repository configuration:

- `WINDOWS_SIGN_CERT_BASE64`: base64-encoded production OV certificate.
- `WINDOWS_SIGN_CERT_PASSWORD`: certificate password.
- `WINDOWS_SIGNTOOL_PATH`: runner path to Microsoft's `signtool.exe`.
- `WINDOWS_SIGN_TIMESTAMP_URL`: trusted RFC3161 timestamp endpoint.

The certificate and password must only exist in GitHub Actions secrets. Never
commit them or print them in logs. The workflow intentionally fails until
production signing is configured.

## Local packaging

Install the Velopack CLI (`dotnet tool install -g vpk`), then run:

```powershell
flutter build windows --release --build-name 1.0.0 --dart-define=STUDIO_VERSION=1.0.0
.\tool\package_windows.ps1 -Version 1.0.0
```

The generated Setup executable and release metadata are in `dist\windows`.
The packaging script also creates the stable `studio-windows-setup.exe` alias
used by the website, so the website always resolves to the latest Windows
installer through GitHub's `releases/latest/download` endpoint.
Unsigned local packages are suitable for testing only.

## Updates and rollback

Installed builds check the official GitHub release feed in the background.
Velopack verifies package integrity before making an update available. Users
can choose **Restart and Update** or continue using the current version.
Development/unpackaged builds ignore update failures and continue normally.

To roll back, mark the broken GitHub release as a draft or remove its assets,
then publish a corrected higher semantic version. Do not reuse a published
version number. Test upgrades by installing a local package for version A,
publishing a private/test version B, and using the installed A build to
download and restart into B.

To verify a signed installer manually:

```powershell
signtool verify /pa Studio-win-*.exe
```
