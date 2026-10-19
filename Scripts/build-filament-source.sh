#!/bin/bash
# Optional, potentially long source build. The default bootstrap uses the official SDK.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
command -v cmake >/dev/null
command -v ninja >/dev/null
source_dir="$root/.build/filament-source"
if [ ! -d "$source_dir/.git" ]; then
  git clone --branch v1.78.0 --depth 1 https://github.com/google/filament.git "$source_dir"
fi
[ "$(git -C "$source_dir" describe --tags --exact-match)" = 'v1.78.0' ] || { echo 'Expected clean v1.78.0 checkout'; exit 1; }
[ -z "$(git -C "$source_dir" status --porcelain)" ] || { echo 'Source tree has local changes; inspect before building'; exit 1; }
cd "$source_dir"
./build.sh -p desktop -i release
./build.sh -p ios -s -i release
# Stage separately: do not silently overwrite the verified prebuilt SDK.
echo "Built SDK: $source_dir/out/ios-release/filament"
echo "To use it, replace Vendor/filament with this SDK, then regenerate the Xcode project."
