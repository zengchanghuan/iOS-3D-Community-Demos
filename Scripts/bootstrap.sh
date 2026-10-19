#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen first: brew install xcodegen'; exit 1; }
if [ ! -f Vendor/filament/lib/libfilament.xcframework/Info.plist ]; then
  archive=$(mktemp /tmp/community3d-filament.XXXXXX)
  trap 'rm -f "$archive"' EXIT
  curl -fL --retry 3 https://github.com/google/filament/releases/download/v1.78.0/filament-v1.78.0-ios.tgz -o "$archive"
  echo "a5476b14496401847854f9aa26a1c11e2e6b3d77a3834d1deedc762abf025242  $archive" | shasum -a 256 -c -
  mkdir -p Vendor/filament
  tar -xzf "$archive" -C Vendor/filament --strip-components=1
fi
xcodegen generate
