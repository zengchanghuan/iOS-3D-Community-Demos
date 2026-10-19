# Dependencies

- GLTFSceneKit: https://github.com/magicien/GLTFSceneKit
  - Vendored `Sources`, `Package.swift`, `LICENSE` from commit `a9587ec5c6515ee7d036533fdd909815a9a718ef`.
  - MIT license retained, no source modifications.
- Filament: https://github.com/google/filament/releases/tag/v1.78.0
  - Official iOS XCFramework SDK; downloaded by `Scripts/bootstrap.sh`, not committed.
  - Apache 2.0 license contained in SDK. Its build is not claimed as a local source build.
  - iOS archive SHA256: `a5476b14496401847854f9aa26a1c11e2e6b3d77a3834d1deedc762abf025242`.
  - Host tools archive SHA256: `dc2fbc7681998842e85ccc211ed1292b15631a97731fa49ef07c2698870ce9c5`.
- ARM astc-encoder 5.7.0: https://github.com/ARM-software/astc-encoder/releases/tag/5.7.0
  - Used offline only, not linked or redistributed.
  - macOS universal ZIP SHA256: `374b2f0aea1d3ab5f849784666d6ece6e27b4bc1f945e5c90d6eeabf00e955f8`.

To build Filament from source instead, check out exactly `v1.78.0` and follow its [build manual](https://github.com/google/filament/blob/v1.78.0/BUILDING.md) for the iOS device and simulator targets. Do not mix headers and libraries from different versions. This repository uses the official release for reproducible integration.

An optional source-build entry point is provided at `Scripts/build-filament-source.sh` (requires CMake and Ninja). It builds host tools and iOS device/simulator XCFrameworks into `.build/filament-source/out/ios-release/filament`; it does not overwrite the release SDK automatically. This source-build path has not been executed as part of the current validation.
