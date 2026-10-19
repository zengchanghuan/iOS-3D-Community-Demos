#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ASTCENC:?Set ASTCENC to ARM astcenc 5.7.0 executable}"
: "${CMGEN:?Set CMGEN to Filament 1.78.0 cmgen executable}"
python3 Scripts/generate-assets.py
"$ASTCENC" -cs App/Resources/Checker.png App/Resources/Checker.astc 4x4 -medium
staging=$(mktemp -d /tmp/community3d-ibl.XXXXXX)
trap 'rm -rf "$staging"' EXIT
"$CMGEN" --quiet --deploy="$staging/Studio" --format=ktx --size=128 App/Resources/Studio.hdr
cp "$staging/Studio/Studio_ibl.ktx" App/Resources/Studio_ibl.ktx
cp "$staging/Studio/Studio_skybox.ktx" App/Resources/Studio_skybox.ktx
