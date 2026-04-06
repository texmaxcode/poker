# Windows packaging (Texas Hold'em Gym)

Build a self-contained folder (or ZIP) with `Poker.exe`, Qt 6 DLLs, plugins, QML imports, and `sqlite3.dll`.

## Prerequisites

- **Visual Studio 2022** (MSVC) *or* **Ninja** + a C++ compiler
- **CMake** ≥ 3.26
- **Qt 6.10** (Desktop, MSVC 2022 64-bit recommended), e.g. from the [Qt Online Installer](https://www.qt.io/download)
- **SQLite3** for Windows — easiest via **vcpkg** (see repo root `vcpkg.json`)

### vcpkg (recommended)

```bat
git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
C:\vcpkg\bootstrap-vcpkg.bat
set VCPKG_ROOT=C:\vcpkg
C:\vcpkg\vcpkg install sqlite3:x64-windows
```

Configure CMake with:

```bat
set CMAKE_TOOLCHAIN_FILE=C:\vcpkg\scripts\buildsystems\vcpkg.cmake
```

## Build & package

From the **repository root**:

```powershell
cd poker\packaging\windows
$env:CMAKE_PREFIX_PATH = "C:\Qt\6.10.0\msvc2022_64"
$env:VCPKG_ROOT = "C:\vcpkg"
.\build-release.ps1
```

Artifacts:

- Staged tree: `dist\windows\` (under repo root)
- ZIP: `TexasHoldemGym-Windows-x64-<githash>.zip` (repo root; hash from `git rev-parse --short=8`)

Override paths:

```powershell
.\build-release.ps1 -QtRoot "C:\Qt\6.10.0\msvc2022_64" -BuildDir "C:\tmp\poker-build" -StagingDir "C:\tmp\out"
```

### Without PowerShell

```bat
cd poker\packaging\windows
set CMAKE_PREFIX_PATH=C:\Qt\6.10.0\msvc2022_64
set VCPKG_ROOT=C:\vcpkg
build-release.cmd
```

## What the script does

1. Configures CMake in **Release** (Ninja if `ninja` is on `PATH`, else multi-config Visual Studio).
2. Builds target `Poker`.
3. Copies `Poker.exe` to the staging folder.
4. Copies `sqlite3.dll` from vcpkg when `VCPKG_ROOT` is set.
5. Runs Qt’s **`windeployqt`** with `--qmldir` pointing at `poker/qml` so Quick/QML is included.
6. Optionally zips the staging directory.

## Installer (.exe setup)

This repo does not generate an MSI/NSIS installer by default. You can wrap `dist\windows` with [WiX](https://wixtoolset.org/), [Inno Setup](https://jrsoftware.org/isinfo.php), or ship the ZIP as on the website.

## GitHub Actions

See `.github/workflows/build-desktop.yml` for an automated Windows build using vcpkg + Qt + `windeployqt`.
