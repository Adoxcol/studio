#!/usr/bin/env bash
# Persistent Linux x64 SDK installation for the trusted homelab runner.
set -euo pipefail

version="${FLUTTER_VERSION:?Set an exact FLUTTER_VERSION}"
cache_root="${FLUTTER_CACHE_ROOT:-/opt/ci/cache/flutter}"
pub_cache="${PUB_CACHE:-/opt/ci/cache/pub}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'An exact stable SDK version is required.' >&2; exit 1; }
[[ "$cache_root" == /* && "$cache_root" != / ]] || { echo 'An absolute dedicated cache directory is required.' >&2; exit 1; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'This cache is Linux x64 only.' >&2; exit 1; }

mkdir -p "$cache_root/downloads" "$pub_cache"
exec 9>"$cache_root/.install.lock"
flock -w 900 9
sdk_parent="$cache_root/stable-$version-x64"
archive="$cache_root/downloads/flutter_linux_$version-stable.tar.xz.part"
staging=''
cleanup() {
  # Only delete a staging directory created by this invocation, never the cache.
  if [[ -n "$staging" && "$staging" == "$cache_root"/.install-* ]]; then
    rm -rf -- "$staging"
  fi
}
trap cleanup EXIT

if [[ -x "$sdk_parent/flutter/bin/flutter" && -f "$sdk_parent/.studio-verified-sha256" ]]; then
  echo "Using verified cached Flutter $version: $sdk_parent/flutter"
else
  [[ ! -e "$sdk_parent" ]] || { echo "Incomplete SDK at $sdk_parent; inspect it before retrying." >&2; exit 1; }
  manifest=$(curl --fail --silent --show-error --location --connect-timeout 15 --max-time 120 --retry 5 \
    https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)
  release=$(jq -ce --arg version "$version" \
    '[.releases[] | select(.version == $version and .channel == "stable" and (.dart_sdk_arch // "x64") == "x64")][0] // error("SDK not found")' <<<"$manifest")
  expected=$(jq -r '.sha256' <<<"$release")
  relative_archive=$(jq -r '.archive' <<<"$release")
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || { echo 'Invalid SDK checksum in release manifest.' >&2; exit 1; }
  [[ "$relative_archive" == "stable/linux/flutter_linux_$version-stable.tar.xz" ]] || { echo 'Unexpected SDK archive path.' >&2; exit 1; }
  verify_archive() {
    [[ -f "$archive" ]] && printf '%s  %s\n' "$expected" "$archive" | sha256sum --check --status
  }
  if ! verify_archive; then
    echo "Downloading/resuming Flutter $version into $archive"
    curl --fail --show-error --location --connect-timeout 15 --max-time 8400 \
      --retry 5 --retry-delay 5 --continue-at - --output "$archive" \
      "https://storage.googleapis.com/flutter_infra_release/releases/$relative_archive"
  fi
  verify_archive || { echo "SDK checksum failed. Preserve $archive for inspection; it has not been installed." >&2; exit 1; }
  staging=$(mktemp -d "$cache_root/.install-$version.XXXXXX")
  tar --extract --xz --no-same-owner --file "$archive" --directory "$staging"
  [[ -x "$staging/flutter/bin/flutter" ]] || { echo 'SDK archive has no executable Flutter tool.' >&2; exit 1; }
  printf '%s\n' "$expected" > "$staging/.studio-verified-sha256"
  mv -- "$staging" "$sdk_parent"
  staging=''
  # The verified SDK is installed; the separate compressed download is redundant.
  rm -- "$archive"
  echo "Installed verified Flutter $version: $sdk_parent/flutter"
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'FLUTTER_ROOT=%s/flutter\nPUB_CACHE=%s\n' "$sdk_parent" "$pub_cache" >> "$GITHUB_ENV"
fi
if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s/flutter/bin\n%s/flutter/bin/cache/dart-sdk/bin\n%s/bin\n' "$sdk_parent" "$sdk_parent" "$pub_cache" >> "$GITHUB_PATH"
fi
