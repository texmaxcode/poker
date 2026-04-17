# macOS packaging (Texas Hold'em Gym)

Produces a **`.app` bundle** (required for Gatekeeper and `macdeployqt`) and a **`.dmg`** for distribution.

## Prerequisites

- **Xcode** (Command Line Tools sufficient for linking)
- **CMake** ≥ 3.26, **Ninja**
- **Qt 6.10** Desktop for macOS (e.g. `clang_64` kit from the [Qt Online Installer](https://www.qt.io/download))
- **SQLite** (Homebrew): `brew install sqlite`

Ensure CMake finds Qt and SQLite, e.g.:

```bash
export CMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/macos"
# optional if FindSQLite3 fails:
export SQLite3_ROOT="$(brew --prefix sqlite)"
```

## Build & package

From the **repository root**:

```bash
chmod +x poker/packaging/macos/build-release.sh
export CMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/macos"
./poker/packaging/macos/build-release.sh
```

Artifacts:

- `build-macos/poker/Poker.app` — Qt frameworks embedded by `macdeployqt` (with `-libpath=$(brew --prefix sqlite)/lib` so Homebrew's `libsqlite3.dylib` is pulled in and its `LC_LOAD_DYLIB` rewritten to `@rpath/...`), then **ad-hoc signed** (`codesign --force --deep --sign -`) so embedded dylibs validate under dyld
- `dist/macos/TexasHoldemGym-macOS-arm64-<githash>.dmg` or `…-x86_64-…` (architecture from `uname -m`)

After `macdeployqt`, the script walks the bundle with `otool -L` and **fails the build** if any `Poker` or embedded dylib/framework still references `/opt/homebrew/...` or `/usr/local/...` — so a missing Homebrew dependency is caught at build time rather than at launch (where it would be a `dyld: Library not loaded` crash on a user's machine).

Override build dir: `BUILD_DIR=/tmp/poker-build ./poker/packaging/macos/build-release.sh`

The DMG is built with **`hdiutil`** after signing so the image contains a consistently signed bundle. (Building the DMG with `macdeployqt -dmg` *before* signing can ship an app that crashes at launch with **Code Signature Invalid** / **CODESIGNING Invalid Page** while dyld loads a Qt library.)

## Notarization (distribution outside the Mac App Store)

Ad-hoc signing (`-`) is enough for local and CI builds; other Macs may need **Right-click → Open** the first time. For wide distribution, use a **Developer ID** identity with `codesign` and **`xcrun notarytool`** / **`stapler`**. This repo does not automate Developer ID signing or notarization; add signing secrets in CI if you need it.

## GitHub Actions

See `.github/workflows/ci.yml` — macOS job on `macos-latest`, uploads the DMG as an artifact.
