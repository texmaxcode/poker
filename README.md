# Texas Hold’em Gym

<p align="center">
  <img src="poker/qml/assets/images/logo.png" alt="Texas Hold'em Gym logo" width="420">
</p>

**Texas Hold’em Gym** is a desktop playground for no-limit Texas Hold’em: a live table with bots, range/strategy setup, and preflop **solver + Monte Carlo equity** tools. The UI is **Qt 6 (QML / Qt Quick)**; game logic, evaluation, and tests are **C++17**.

## What’s in the box

- **Lobby & table** — configurable blinds and stacks; human vs bots; sit-out; timed decisions; pot + call indicator; Min / ⅓ / ½ / ⅔ / Pot / All bet-sizing presets.
- **Bots & ranges** — per-seat bot style and editable opening ranges (matrix / text).
- **Solver & equity** — preflop solver and equity runs (work is off the UI thread where applicable).
- **Core engine** — full hand from deal through showdown: blinds, streets, betting order, hand evaluation (best five of seven), simplified pot award (see [Rules & limitations](docs/rules-and-limitations.md)).

## Repository layout

| Path | Role |
|------|------|
| `CMakeLists.txt` | Top-level CMake: Qt 6, C++17, tests |
| `build.sh` | Optional script: clean configure, **Ninja** build, `ctest`, then runs the app |
| `poker/main.cpp` | `QGuiApplication`, QML engine, exposes `pokerGame` (`game`) and `pokerSolver` |
| `poker/qml/` | QML UI; assets and `application.qrc` |
| `poker/poker/` | Cards, player, `game` + `game_ui_sync` (QML sync), hand eval, bots, ranges, equity, solver, session store; **Boost.Test** smoke tests |

## Dependencies (summary)

You need a **toolchain**, **CMake**, **Qt 6.10+** (Quick stack), and **Boost** (headers + `unit_test_framework` for tests). See **[Building](docs/building.md)** for versions, optional tools, distro packages, environment variables, and troubleshooting.

| Requirement | Notes |
|-------------|--------|
| CMake | **3.26+** (`cmake_minimum_required` in tree) |
| C++ compiler | **C++17** (GCC, Clang, MSVC supported in principle) |
| Qt 6 | **≥ 6.10** — components: **Core**, **Gui**, **Qml**, **Quick** (Quick pulls Gui/OpenGL stack on many platforms) |
| Boost | **≥ 1.70** — **unit_test_framework** only (for `Test_poker`) |
| Build backend | **Ninja** recommended (used by `build.sh`); Makefile generators work too |

## Build (quick)

Point CMake at your Qt install prefix (the directory that contains `lib/cmake/Qt6`):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=/path/to/Qt/6.10.0/gcc_64
cmake --build build -j
ctest --test-dir build --output-on-failure
```

Convenience script (expects `QT_LIBS` or defaults in the script — edit for your machine):

```bash
QT_LIBS=/path/to/Qt/6.10.0/gcc_64 ./build.sh
```

**Run** (binary name and path):

```bash
./build/poker/Poker
```

The app starts on the **lobby**; navigate to the **table**, **bots & ranges**, or **solver & equity** screens. The live table page is `Game.qml` (`objectName: game_screen`), connected after load so the engine can sync state.

### Saved configuration

Table stakes, per-seat bot strategy and range text (exported form), **sit out**, and **solver & equity** field values are stored with **`QSettings`** under organization **`TexasHoldemGym`** / application **`Texas Hold'em Gym`** (e.g. `~/.config/TexasHoldemGym/` on Linux). They load at startup and save on quit and when you apply stakes, change a bot strategy, apply range text, reset a seat to full range, toggle sit out, or close the window (solver tab).

## Documentation

| Document | Contents |
|----------|----------|
| [docs/building.md](docs/building.md) | Full dependency list, configure variables, OS notes, Qt commercial / license service env, tests, card assets script |
| [docs/architecture.md](docs/architecture.md) | App shell, QML ↔ C++, modules, tests |
| [docs/rules-and-limitations.md](docs/rules-and-limitations.md) | Alignment with standard Hold’em, heads-up blinds, side pots, intentional simplifications |

## Tests

```bash
ctest --test-dir build --output-on-failure
```

The registered suite is the **Boost.Test** smoke binary `Test_poker` (`poker/poker/tests/test.cpp`).
