#!/usr/bin/env bash
# Network-free smoke tests with a tiny SDK fixture, never the real cache.
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/source/flutter/bin" "$fixture/bin"
printf '#!/bin/sh\nexit 0\n' > "$fixture/source/flutter/bin/flutter"
chmod +x "$fixture/source/flutter/bin/flutter"
tar -cJf "$fixture/sdk.tar.xz" -C "$fixture/source" flutter
checksum=$(sha256sum "$fixture/sdk.tar.xz" | cut -d ' ' -f 1)
printf '{"releases":[{"version":"3.47.2","channel":"stable","dart_sdk_arch":"x64","sha256":"%s","archive":"stable/linux/flutter_linux_3.47.2-stable.tar.xz"}]}\n' "$checksum" > "$fixture/manifest.json"
cat > "$fixture/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -eu
[[ "${OFFLINE:-0}" == 0 ]] || { echo 'Unexpected network access on warm cache' >&2; exit 1; }
if [[ "${*: -1}" == */releases_linux.json ]]; then
  cat "$FIXTURE/manifest.json"
else
  output=''
  resume=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output="$2"; shift ;;
      --continue-at) [[ "$2" == - ]]; resume=true; shift ;;
    esac
    shift
  done
  [[ "$resume" == true && -n "$output" ]]
  if [[ "${CORRUPT:-0}" == 1 ]]; then
    printf 'corrupt archive' > "$output"
  else
    cp "$FIXTURE/sdk.tar.xz" "$output"
  fi
fi
MOCK
chmod +x "$fixture/bin/curl"
export FIXTURE="$fixture" PATH="$fixture/bin:$PATH" FLUTTER_VERSION=3.47.2
export FLUTTER_CACHE_ROOT="$fixture/cache" PUB_CACHE="$fixture/pub"
export GITHUB_ENV="$fixture/github-env" GITHUB_PATH="$fixture/github-path"
mkdir -p "$FLUTTER_CACHE_ROOT/downloads"
printf partial > "$FLUTTER_CACHE_ROOT/downloads/flutter_linux_3.47.2-stable.tar.xz.part"
bash "$script_dir/setup-flutter-cache.sh"
test -x "$FLUTTER_CACHE_ROOT/stable-3.47.2-x64/flutter/bin/flutter"
grep -Fq "$FLUTTER_CACHE_ROOT/stable-3.47.2-x64/flutter/bin" "$GITHUB_PATH"
grep -Fq "PUB_CACHE=$PUB_CACHE" "$GITHUB_ENV"
test ! -f "$FLUTTER_CACHE_ROOT/downloads/flutter_linux_3.47.2-stable.tar.xz.part"
OFFLINE=1 bash "$script_dir/setup-flutter-cache.sh"
export FLUTTER_CACHE_ROOT="$fixture/corrupt-cache"
if CORRUPT=1 bash "$script_dir/setup-flutter-cache.sh"; then
  echo 'Checksum mismatch was incorrectly accepted' >&2
  exit 1
fi
test ! -e "$FLUTTER_CACHE_ROOT/stable-3.47.2-x64"
test -f "$FLUTTER_CACHE_ROOT/downloads/flutter_linux_3.47.2-stable.tar.xz.part"
echo 'SDK cache tests passed (resume, install, offline reuse, environment, corrupt archive).'
