# Poker

Texas Hold’em playground / solver UI built with **Qt 6 (QML/Quick)** and **C++**.

## Project layout

- `CMakeLists.txt`: top-level build (Qt6 required)
- `build.sh`: convenience build script (expects a Qt install path)
- `poker/`
  - `main.cpp`: Qt/QML entrypoint
  - `qml/`: QML UI (resources are embedded via `application.qrc`)
  - `poker/`: core game / cards / player logic + unit tests

## Prerequisites

- **CMake** 3.26+
- A C++17 compiler
- **Qt 6.10+** (Core, Gui, Qml, Quick)
- **Boost** (for unit tests: `unit_test_framework`)

On Linux you typically need the Qt *development* packages or a Qt SDK install and then set `CMAKE_PREFIX_PATH` (or `Qt6_DIR`) so CMake can find `Qt6Config.cmake`.

## Build

### CMake (recommended)

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=/path/to/Qt/6.10.*/gcc_64
cmake --build build -j
```

### Convenience script

```bash
QT_LIBS=/path/to/Qt/6.10.*/gcc_64 ./build.sh
```

## Run

```bash
./build/poker/Poker
```

## Tests

```bash
ctest --test-dir build --output-on-failure
```

## Docs

See `docs/`:

- `docs/building.md`
- `docs/architecture.md`

