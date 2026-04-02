# Architecture overview

## High-level picture

Texas Hold’em Gym is a **single-process** desktop app: a **Qt Quick** UI drives a **C++** game engine (`game`), optional **bot** and **range** configuration, **hand evaluation** and **equity** utilities, a **preflop solver** façade (`pokerSolver`), a **toy Nash** study helper (`toyNashSolver`), and **training** drills (`TrainingController` + `TrainingStore`). There is **no SQL database**; table state is in memory, while **QSettings** (and small JSON assets) persist configuration and progress on disk.

```
┌─────────────────────────────────────────────────────────────────┐
│  QML (Main.qml, Lobby, Game, SetupScreen, Stats, trainers, …)   │
│       │ signals / setProperty / context properties                │
│       ▼                                                         │
│  game · PokerSolver · ToyNashSolver · TrainingController · stores │
│       │                                                         │
│       ├── cards, player, hand_eval, bot, range_matrix           │
│       ├── equity_engine, poker_solver (may use threads)        │
│       ├── training_store, training_controller, toy_nash_solver │
│       └── session_store (solver UI fields)                       │
└─────────────────────────────────────────────────────────────────┘
```

## Application shell

- **`poker/main.cpp`** sets `QCoreApplication` organization/name for **`QSettings`**, creates **`game`**, calls **`loadPersistedSettings()`**, instantiates **`PokerSolver`**, **`ToyNashSolver`**, **`SessionStore`**, **`TrainingStore`**, **`TrainingController`**, and exposes **`pokerGame`**, **`pokerSolver`**, **`toyNashSolver`**, **`sessionStore`**, **`trainingStore`**, **`trainer`**, and **`appFontFamily`** to QML. **`aboutToQuit`** saves table-related settings.
- The UI entry is **`qrc:/Main.qml`**: an `ApplicationWindow` with a **stack** of pages (lobby, table, bot/range setup, solver/equity, bankroll/stats, training hub, preflop trainer, flop trainer). Fonts and the header/toolbar live on the window.
- After **`QQmlApplicationEngine::load()`**, a short **`QTimer::singleShot`** finds the table **`Page`** by **`objectName: "game_screen"`**, calls **`game::setRootObject()`** on it, then **`beginNewHand()`** so the first hand starts only when the table is ready. The engine does **not** use `Game.qml` as the root object.

## Game ↔ QML

- **`game`** holds `QObject* m_root` to the table **`Page`**. It connects to **`buttonClicked(QString)`** for HUD actions (fold, call, check, raise, “more time”) from **`GameControls`**.
- Betting runs in C++; when the human must act, the code can spin a **local event loop** (with timers) until QML submits an action via **`submitFacingAction`**, **`submitCheckOrBet`**, etc.
- State is pushed to QML with **`QObject::setProperty`** on the root: pot, board card asset names, per-seat stacks/cards/in-hand flags, button/SB/BB seats, acting seat, timers, hand sequence counter, and related fields. **`sync_ui()`** centralizes this; **`pot_changed`** triggers a pot-only refresh.
- The live path for a new hand is **`beginNewHand()`** → **`start()`** (full hand through streets and **`do_payouts()`** when appropriate). **`game::start()`** remains usable from tests or automation.

## Core C++ modules (`poker/poker/`)

| Module | Responsibility |
|--------|----------------|
| **`cards.*`** | Ranks, suits, deck; compact string form + **`card_to_qml_asset_path`** for SVG resource names |
| **`player.*`** | Hole cards, stack, **`pay`** / **`take_from_stack`** (clamped) |
| **`hand_eval.*`** | Best 5 of 7, comparison, human-readable descriptions |
| **`game.*` / `game_ui_sync.cpp`** | Table vector, button, blinds, streets, **`in_hand`**, betting loop, bots, persistence, QML API; **`sync_ui`** / **`flush_ui`** in **`game_ui_sync.cpp`** |
| **`session_store.*`** | **`QSettings`** load/save for solver screen fields |
| **`training_store.*`** / **`training_controller.*`** | Persisted training progress; prefop/flop drill generation and scoring |
| **`bot.*`** | Bot strategy enums and decision hooks used from **`game`** |
| **`range_matrix.*`** | Parsing and weights for opening ranges |
| **`equity_engine.*`** | Monte Carlo equity helpers for the solver UI |
| **`poker_solver.*`** | QObject façade for solver work; may delegate to worker/thread pool |
| **`toy_nash_solver.*`** | Small Kuhn-style CFR solver for study UI |

## QML structure (selected)

| File / area | Role |
|-------------|------|
| **`Main.qml`** | Shell: navigation, **`pokerGame`** / **`pokerSolver`** / **`trainer`** bindings |
| **`Lobby.qml`** | Entry: logo + tiles to table, setup, solver, training, stats |
| **`Game.qml`** | Table layout, **`game_screen`**, **`Player`** delegates, **`GameControls`** |
| **`GameControls.qml`**, **`SizingPresetBar.qml`** | Fold / call / raise / check / bet, timers, sit-out; Min / ⅓ / ½ / ⅔ / Pot / All presets |
| **`Table.qml`** | Pot HUD (with call amount), community board cards |
| **`SetupScreen.qml`**, **`SolverScreen.qml`** | Ranges, strategies, solver/equity UI |
| **`StatsScreen.qml`** | Bankroll tables, leaderboard, chart |
| **`TrainerHome.qml`**, **`PreflopTrainer.qml`**, **`FlopTrainer.qml`** | Training hub and drills |

Bundled training JSON lives under **`poker/qml/assets/training/`** (e.g. `preflop_ranges_v1.json`, `spots_v1.json`). Assets are embedded via **`application.qrc`**.

## Rules and engine fidelity

Betting order, blinds (including **heads-up**), burns before board cards, showdown messaging, **side pots** (HUD: shortest all-in defines the main pot; deeper stacks contest sides), and **best hand** selection follow the intended Hold’em model; some **simplifications** still apply. See **[rules-and-limitations.md](rules-and-limitations.md)**.

## Tests

- **`poker/poker/tests/test.cpp`** — **Boost.Test** smoke tests: includes **`game.hpp`** (plus hand eval / range / equity headers); covers **`collect_blinds`**, **`deal_*`**, **`take_bets_for_testing`**, **`decide_the_payout`**, etc.
- **`poker/poker/tests/CMakeLists.txt`** registers **`poker.smoke`** via **`add_test`** when **`BUILD_TESTING`** is on.

The **`poker`** library links **Qt::Qml** so MOC’d types used from tests stay consistent with the app’s Qt linkage.
