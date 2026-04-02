# Texas Hold’em Gym

<p align="center">
  <img src="poker/qml/assets/images/logo.png" alt="Texas Hold'em Gym logo" width="420">
</p>

**Texas Hold’em Gym** is a desktop playground for no-limit Texas Hold’em: a live table with bots, range/strategy setup, preflop **solver + Monte Carlo equity** tools, **preflop and flop training drills**, and **bankroll / stats** tracking. The UI is **Qt 6 (QML / Qt Quick)**; game logic, evaluation, and tests are **C++17**.

## What’s in the box

- **Lobby & table** — configurable blinds and stacks; human vs bots; sit-out; timed decisions; pot + call indicator; Min / ⅓ / ½ / ⅔ / Pot / All bet-sizing presets.
- **Bots & ranges** — per-seat bot style and editable opening ranges (matrix / text); per-seat **buy-in** capped at **100× big blind**, with excess bankroll **off the table** (see [Rules & limitations](docs/rules-and-limitations.md)).
- **Solver & equity** — Monte Carlo equity vs a range or exact villain cards, with optional pot-odds and chip-EV (work is off the UI thread where applicable); toy Nash (Kuhn-style) solver for study.
- **Training** — **Preflop** and **Flop** drills with strategy-based grading, progress stats (accuracy, EV loss in bb), and configurable auto-advance delay.
- **Bankroll & stats** — seat stacks, off-table bankroll, leaderboard, and bankroll-over-time chart after each completed hand.
- **Core engine** — full hand from deal through showdown: blinds, streets, betting order, hand evaluation (best five of seven), simplified pot award (see [Rules & limitations](docs/rules-and-limitations.md)).

## Repository layout

| Path | Role |
|------|------|
| `CMakeLists.txt` | Top-level CMake: Qt 6, C++17, optional tests |
| `build.sh` | Optional script: clean configure, **Ninja** build, `ctest`, then runs the app |
| `poker/main.cpp` | `QGuiApplication`, QML engine; exposes **`pokerGame`** (`game`), **`pokerSolver`**, **`toyNashSolver`**, **`sessionStore`** (solver fields), **`trainingStore`**, **`trainer`** (`TrainingController`), **`appFontFamily`** |
| `poker/qml/` | QML UI; assets and `application.qrc` |
| `poker/poker/` | Cards, player, `game` + `game_ui_sync`, hand eval, bots, ranges, equity, solver, toy Nash, **training** store/controller, session store; **Boost.Test** smoke tests (optional) |

## Dependencies (summary)

You need a **toolchain**, **CMake**, **Qt 6.10+** (Quick stack), and **Boost** (headers + `unit_test_framework`) **only if you build tests** (`BUILD_TESTING` ON, default). See **[Building](docs/building.md)** for versions, optional tools, distro packages, environment variables, and troubleshooting.

| Requirement | Notes |
|-------------|--------|
| CMake | **3.26+** (`cmake_minimum_required` in tree) |
| C++ compiler | **C++17** (GCC, Clang, MSVC supported in principle) |
| Qt 6 | **≥ 6.10** — components: **Core**, **Gui**, **Qml**, **Quick** (Quick pulls Gui/OpenGL stack on many platforms) |
| Boost | **≥ 1.70** — **unit_test_framework** only, for `Test_poker` when tests are enabled |
| Build backend | **Ninja** recommended (used by `build.sh`); Makefile generators work too |

## Build (quick)

Point CMake at your Qt install prefix (the directory that contains `lib/cmake/Qt6`):

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_PREFIX_PATH=/path/to/Qt/6.10.0/gcc_64
cmake --build build -j
ctest --test-dir build --output-on-failure
```

To configure **without** tests (no Boost required): `-DBUILD_TESTING=OFF`.

Convenience script (expects `QT_LIBS` or defaults in the script — edit for your machine):

```bash
QT_LIBS=/path/to/Qt/6.10.0/gcc_64 ./build.sh
```

**Run** (binary name and path):

```bash
./build/poker/Poker
```

The app starts on the **lobby**; navigate to the **table**, **bots & ranges**, **solver & equity**, **training**, or **bankroll & stats**. The live table page is `Game.qml` (`objectName: game_screen`), connected after load so the engine can sync state.

### Saved configuration

Table stakes, per-seat bot strategy and range text (exported form), per-seat **buy-in** and related bankroll fields, **sit out**, **solver & equity** field values, **trainer** auto-advance / decision time, and **training progress** are stored with **`QSettings`** under organization **`TexasHoldemGym`** / application **`Texas Hold'em Gym`** (e.g. `~/.config/TexasHoldemGym/` on Linux). They load at startup and save on quit and when you apply stakes, change a bot strategy, apply range text, reset a seat to full range, toggle sit out, close the window (solver tab), or when training/session stores persist.

## Documentation

| Document | Contents |
|----------|----------|
| [docs/building.md](docs/building.md) | Full dependency list, configure variables, OS notes, Qt commercial / license service env, tests, card assets script |
| [docs/architecture.md](docs/architecture.md) | App shell, QML ↔ C++, modules, tests |
| [docs/rules-and-limitations.md](docs/rules-and-limitations.md) | Alignment with standard Hold’em, heads-up blinds, side pots, stake/bankroll rules, intentional simplifications |
| [docs/mvp-trainer-roadmap.md](docs/mvp-trainer-roadmap.md) | Trainer roadmap (see status note at top of that file if present) |

## Tests

```bash
ctest --test-dir build --output-on-failure
```

When `BUILD_TESTING` is on, the suite is the **Boost.Test** smoke binary `Test_poker` (`poker/poker/tests/test.cpp`).
