# Building Texas Hold’em Gym

This document lists **what you need to build and test** the project, how to configure CMake, and common problems.

## Required software

### CMake

- **Version:** **3.26 or newer** (see root `CMakeLists.txt`).
- Install from your OS package manager, [Kitware](https://cmake.org/download/), or a dev stack (e.g. Visual Studio includes a generator).

### C++ toolchain

- **Language:** **C++17** (`CMAKE_CXX_STANDARD 17`).
- **Tested in CI-style use:** GCC and Clang on Linux; MSVC should work with Qt’s supported compilers.
- Set explicitly if you use `build.sh`, which passes `C` and `CXX` (default `/usr/bin/gcc` and `/usr/bin/g++`).

### Qt 6

- **Minimum version:** **6.10** (`find_package(Qt6 6.10 REQUIRED ...)`).
- **Required CMake packages / components:**
  - **Core**
  - **Gui**
  - **Qml**
  - **Quick**

The **Poker** executable links Core, Gui, Quick, and Qml. The **poker** static library uses Core and Qml (MOC may pull additional Qt tooling).

**Finding Qt:** CMake must locate `Qt6Config.cmake`. Typical layouts:

- Offline installer (Linux x64): `~/Qt/6.10.0/gcc_64` (prefix contains `lib/cmake/Qt6`)
- Distribution packages: often under `/usr/lib/cmake/Qt6` or similar

**Variables:**

| Variable | Purpose |
|----------|---------|
| `CMAKE_PREFIX_PATH` | Preferred: set to the Qt **prefix** (parent of `lib/cmake/Qt6`) |
| `Qt6_DIR` | Alternative: directory containing `Qt6Config.cmake` |

Example configure:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/gcc_64"
```

### Boost

- **Only required when tests are enabled** (CMake **`BUILD_TESTING`** is **ON** by default; pass **`-DBUILD_TESTING=OFF`** to skip tests and omit Boost).
- **Minimum version:** **1.70** (`find_package(Boost 1.70 REQUIRED COMPONENTS unit_test_framework)` in the tests subtree).
- **Component used:** **unit_test_framework** only (links into `Test_poker`).
- You need **development** packages: headers plus the compiled test library (often `libboost-test-dev` or `boost-devel` on Linux).

### Optional but recommended

| Tool | Role |
|------|------|
| **Ninja** | Fast incremental builds; `build.sh` uses `-G Ninja` |
| **ctest** | Comes with CMake; runs the registered tests |
| **ccache** | Speeds rebuilds if you wrap the compiler |

## Transitive / system libraries (Qt Quick)

Qt **Quick** often uses **OpenGL** (or ANGLE on Windows) for rendering. On Linux you may need Mesa/OpenGL dev packages if linking fails. CMake may report **Vulkan** headers as optional (`WrapVulkanHeaders`); the project does not require Vulkan explicitly—treat missing Vulkan as optional unless your Qt build demands it.

## Environment variables

| Variable | When to set |
|----------|-------------|
| `CMAKE_PREFIX_PATH` / `Qt6_DIR` | Always, if Qt is not on CMake’s default search path |
| `QTFRAMEWORK_BYPASS_LICENSE_CHECK=1` | Some **commercial** Qt 6 installs run a license service for **moc**/**rcc**/**runtime**. Setting this to **1** skips that check (see Qt docs / your installer). The repo’s `build.sh` sets a default so local builds do not block on the license daemon. |
| `DESTDIR` | For staged installs if you add `cmake --install` later |

## Build steps

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH="/path/to/Qt/6.10.0/gcc_64"
cmake --build build -j
```

Release:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="..."
cmake --build build -j
```

## Tests

```bash
ctest --test-dir build --output-on-failure
```

This runs the **`poker.unit`** test (`Test_poker` executable).

## Convenience script (`build.sh`)

The script:

1. Removes and recreates the build directory (`DESTINATION`, default `./build`)
2. Configures with **Ninja**, `CMAKE_PREFIX_PATH` from **`CMAKE_PREFIX_PATH`** or **`QT_LIBS`** (both must point at your Qt 6 prefix; the script exits with an error if neither is set)
3. Builds
4. Runs **ctest**
5. Launches `./build/poker/Poker`

Override compilers via `C` and `CXX` if needed.

## Card artwork (optional)

Playing-card SVGs live under `poker/qml/assets/cards/` and are listed in `poker/qml/application.qrc`. To refresh from upstream:

```bash
# requires wget
./poker/qml/assets/cards/get_cards_svgs.sh
```

If filenames change, update `application.qrc` accordingly.

## Troubleshooting

### “Could not find a package configuration file provided by Qt6”

- Install Qt 6 **development** files, or set `CMAKE_PREFIX_PATH` / `Qt6_DIR` to the correct prefix.
- Confirm the version is **≥ 6.10**.

### Boost / `unit_test_framework` not found

- Install Boost development packages including the test library.
- On unusual layouts, you can try `-DBoost_ROOT=...` or `CMAKE_PREFIX_PATH` pointing at Boost’s install prefix.

### Commercial Qt / license service / moc errors

- Set `QTFRAMEWORK_BYPASS_LICENSE_CHECK=1` for non-interactive or offline builds if your Qt distribution uses the Qt License Service (see also `build.sh`).

### OpenGL / graphics at runtime

- Ensure GPU drivers and (on Linux) Mesa/libGL are installed so **Qt Quick** can create a scene graph window.
