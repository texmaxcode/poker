# Packaging — Texas Hold'em Gym

| Platform | Location | Output |
|----------|----------|--------|
| **Linux** | [`linux/`](./linux/) | **Snap** ([`snap/snapcraft.yaml`](../../snap/snapcraft.yaml)) for Ubuntu App Center / Snap Store; AppImage; Flatpak YAML; local install scripts |
| **Windows** | [`windows/`](./windows/) | `dist/windows/` + optional `TexasHoldemGym-Windows-x64-<githash>.zip` |
| **macOS** | [`macos/`](./macos/) | `Poker.app`, `dist/macos/TexasHoldemGym-macOS-*.dmg` |

Shared requirements: **CMake** ≥ 3.26, **Qt 6.10** (Quick/QML), **SQLite3** (CMake `SQLite::SQLite3`).

- **Windows**: SQLite via **vcpkg** — use repo root [`vcpkg.json`](../../vcpkg.json) and `-DCMAKE_TOOLCHAIN_FILE=…/vcpkg.cmake`.
- **macOS**: `brew install sqlite` and pass `-DSQLite3_ROOT=$(brew --prefix sqlite)` if needed.

CI: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) runs Linux (build + tests), Windows (ZIP), and macOS (DMG) on every push and pull request in parallel. [`.github/workflows/build-snap.yml`](../../.github/workflows/build-snap.yml) builds the Linux snap when `snap/` or desktop sources change.
