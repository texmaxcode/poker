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

- `build-macos/poker/Poker.app` — Qt frameworks embedded by `macdeployqt`
- `dist/macos/TexasHoldemGym-macOS-arm64.dmg` or `…-x86_64.dmg` (suffix from `uname -m`)

Override build dir: `BUILD_DIR=/tmp/poker-build ./poker/packaging/macos/build-release.sh`

## Notarization (distribution outside the Mac App Store)

Apple requires **notarization** for a smooth “Open” experience on other Macs. After you have a signed `.app` or `.dmg`, use `xcrun notarytool` and `stapler`. This repo does not automate signing/notarization; add secrets in CI if you need it.

## GitHub Actions

See `.github/workflows/ci.yml` — macOS job on `macos-latest`, uploads the DMG as an artifact.
