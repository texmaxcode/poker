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
4. Copies `sqlite3.dll` from vcpkg (`installed\<triplet>\bin`, triplet = `VCPKG_DEFAULT_TRIPLET` or `x64-windows`).
5. Runs Qt’s **`windeployqt`** with `--qmldir` pointing at `poker/qml`, **`--release`**, and **`--compiler-runtime`**. The last flag copies the **MSVC runtime** (`vcruntime*.dll`, `msvcp*.dll`, etc.) next to `Poker.exe` so the app runs on PCs that never installed the [VC++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
6. Walks **PE imports** with **`dumpbin`** (from VS) **recursively** across the staging tree — including `platforms\`, `styles\`, `imageformats\`, `iconengines\`, `sqldrivers\`, `tls\`, and `qml\**` — and copies any **`.dll` still missing** from **vcpkg `installed\<triplet>\bin`** and from **Qt’s `bin`** (first match wins). Covers **vcpkg transitive deps** (e.g. zlib for SQLite, OpenSSL for `tls\qopensslbackend.dll`) and any **Qt DLL** still absent after `windeployqt` (unusual, but safe). If `dumpbin` is not available, use **“x64 Native Tools”** / **Developer PowerShell for VS** or rely on CI.
7. **Verifies** every PE in the staging tree has all its `dumpbin` imports resolved either next to itself, in the staging root, or as a Windows system DLL. The build **fails** if anything is unresolved, so missing DLLs surface at build time instead of as a mystery "entry point not found" dialog on a user's machine.
8. Optionally zips the staging directory.

## Installer (Inno Setup)

CI and local builds can produce a single **`TexasHoldemGym-Setup-<version>-<githash>.exe`** under **`dist\`**.

1. Install [Inno Setup 6](https://jrsoftware.org/isdl.php).
2. Run **`build-release.ps1`** so **`dist\windows`** is complete.
3. From **`poker\packaging\windows`**:

```powershell
.\build-installer.ps1
```

Override staging or compiler:

```powershell
.\build-installer.ps1 -StagingDir "D:\out\windows" -IsccPath "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
```

The script **`TexasHoldemGym.iss`** installs under **Program Files**, Start menu, optional desktop icon, and uninstaller. For **MSI** (enterprise deployment), generate a package with [WiX](https://wixtoolset.org/) using the same **`dist\windows`** tree as source.

**Code signing:** sign **`Poker.exe`** before `build-installer.ps1`, or add a `SignTool` line in the `.iss` file once you have a certificate.

## GitHub Actions

See `.github/workflows/ci.yml`: Windows job runs vcpkg, Qt, **`build-release.ps1`**, Inno Setup, and uploads the ZIP, staged folder, and **`dist\TexasHoldemGym-Setup-*.exe`**.
