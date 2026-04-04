# Architecture overview

## High-level picture

Texas Hold’em Gym is a **single-process** desktop app: a **Qt Quick** UI drives a **C++** game engine (`game`), optional **bot** and **range** configuration, **hand evaluation** and **equity** utilities, a **preflop solver** façade (`pokerSolver`), a **toy Nash** study helper (`toyNashSolver`), and **training** drills (`TrainingController` + `TrainingStore`). **Table state** stays in memory; **configuration and progress** persist via **`AppStateSqlite`** (SQLite with a **QSettings** INI fallback), plus small JSON assets under `qrc`.

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
│       ├── session_store (solver UI fields)                       │
│       └── persist_sqlite (AppStateSqlite KV backend)             │
└─────────────────────────────────────────────────────────────────┘
```

## Application shell

- **`poker/main.cpp`** sets `QCoreApplication` organization/name (used by the INI fallback), calls **`AppStateSqlite::init()`**, creates **`game`**, **`loadPersistedSettings()`**, optionally **`seedMissingPersistedSettings()`** when the store is open but core keys are absent, then **`PokerSolver`**, **`ToyNashSolver`**, **`TrainingStore`**, **`TrainingController`**, **`SessionStore`**, and exposes **`pokerGame`**, **`pokerSolver`**, **`toyNashSolver`**, **`sessionStore`**, **`trainingStore`**, **`trainer`**, and **`appFontFamily`** to QML. **`aboutToQuit`** calls **`savePersistedSettings()`** on the game.
- The UI entry is **`qrc:/Main.qml`**: an `ApplicationWindow` with a **stack** of pages (lobby, table, bot/range setup, solver/equity, bankroll/stats, training hub, preflop trainer, flop trainer). Fonts and the header/toolbar live on the window.
- After **`QQmlApplicationEngine::load()`**, a short **`QTimer::singleShot`** finds the table **`Page`** by **`objectName: "game_screen"`**, calls **`game::setRootObject()`** on it, then **`beginNewHand()`** so the first hand starts only when the table is ready. The engine does **not** use `Game.qml` as the root object.

## Persistence

- **`AppStateSqlite`** (`persist_sqlite.*`) is the shared key–value store. The default database file is **`AppLocalDataLocation/texas-holdem-gym.sqlite`**.
- Set **`TEXAS_HOLDEM_GYM_SQLITE`** to an absolute path to override the database location (tests and debugging).
- **Logical keys** use a versioned prefix, e.g. **`v1/smallBlind`**, **`v1/seat0/strategy`**, **`v1/training/…`**. Bulk deletes use prefix removal (e.g. `v1/training/`).
- **Values** are stored as **JSON** (compact): objects and arrays as JSON documents; scalars are encoded so reads round-trip reliably (including a shim for bare primitives when needed).
- If SQLite cannot be opened, the code falls back to **`QSettings`** in **INI** form under the usual **`~/.config/TexasHoldemGym/`** layout. On first open, an **empty** SQLite database may **migrate** legacy **`v1/*`** data from native QSettings into the DB.

## Data flow (startup → first hand)

1. **`AppStateSqlite::init()`** — open SQLite (or INI fallback), schema, optional migration.
2. **`game::loadPersistedSettings()`** — read **`v1/*`** keys into table state, bankroll, strategies, etc.
3. **`seedMissingPersistedSettings()`** (conditional) — fill only missing keys so a first run does not clobber partial data with a full save.
4. **QML** — build context properties, **`engine.load(Main.qml)`**, window/scene ready.
5. **First hand** — deferred **`setRootObject(game_screen)`** then **`beginNewHand()`** after the table **`Page`** exists.

## Game ↔ QML

- **`game`** holds `QObject* m_root` to the table **`Page`**. It connects to **`buttonClicked(QString)`** for HUD actions (fold, call, check, raise, “more time”) from **`GameControls`**.
- Betting runs in C++; when the human must act, the code can spin a **local event loop** (with timers) until QML submits an action via **`submitFacingAction`**, **`submitCheckOrBet`**, etc.
- State is pushed to QML with **`QObject::setProperty`** on the root: pot, board card asset names, per-seat stacks/cards/in-hand flags, button/SB/BB seats, acting seat, timers, hand sequence counter, and related fields. **`sync_ui()`** centralizes this; **`pot_changed`** triggers a pot-only refresh.
- The live path for a new hand is **`beginNewHand()`** → **`start()`** (full hand through streets and **`do_payouts()`** when appropriate). **`game::start()`** remains usable from tests or automation.

## Core C++ modules (`poker/poker/`)

| Module | Responsibility |
|--------|----------------|
| **`persist_sqlite.*`** | **`AppStateSqlite`**: SQLite KV (JSON values), INI fallback, migration from legacy QSettings |
| **`cards.*`** | Ranks, suits, deck; compact string form + **`card_to_qml_asset_path`** for SVG resource names |
| **`player.*`** | Hole cards, stack, **`pay`** / **`take_from_stack`** (clamped) |
| **`hand_eval.*`** | Best 5 of 7, comparison, human-readable descriptions (order-invariant best-of-seven) |
| **`holdem_side_pot.*`** | Table-stakes **main + side pot** slices — `do_payouts` |
| **`game.*` / `game_ui_sync.cpp`** | Table vector, button, blinds, streets, **`in_hand`**, betting loop, bots, persistence via **`AppStateSqlite`**, QML API; **`sync_ui`** / **`flush_ui`** |
| **`session_store.*`** | Load/save solver screen fields through **`AppStateSqlite`** |
| **`training_store.*`** | Persisted training progress; drill-related data |
| **`training_controller.*`** | Preflop/flop drill generation and scoring |
| **`bot.*`** | Bot strategy enums and decision hooks used from **`game`** |
| **`range_matrix.*`** | Parsing and weights for opening ranges |
| **`equity_engine.*`** | Monte Carlo equity helpers for the solver UI |
| **`poker_solver.*`** | QObject façade for solver work; may delegate to worker/thread pool |
| **`toy_nash_solver.*`** | Small Kuhn-style CFR solver for study UI |

## QML structure (selected)

| File / area | Role |
|-------------|------|
| **`Main.qml`** | Shell: navigation, **`pokerGame`** / **`pokerSolver`** / **`trainer`** bindings |
| **`screens/LobbyScreen.qml`** | Entry: logo + tiles to table, setup, solver, training, stats |
| **`screens/GameScreen.qml`** | Table layout, **`game_screen`**, **`Player`** delegates, **`GameControls`** |
| **`components/GameControls.qml`**, **`components/SizingPresetBar.qml`** | Fold / call / raise / check / bet, timers, sit-out; Min / ⅓ / ½ / ⅔ / Pot / All presets |
| **`components/Table.qml`** | Pot HUD (with call amount), community board cards |
| **`screens/SetupScreen.qml`**, **`screens/SolverScreen.qml`** | Ranges, strategies, solver/equity UI |
| **`screens/StatsScreen.qml`** | Bankroll tables, leaderboard, chart |
| **`screens/TrainerHome.qml`**, **`PreflopTrainer.qml`**, **`FlopTrainer.qml`** | Training hub and drills |
| **`components/GameButton.qml`** | Shared **`hud` / `chrome` / `form` / `chip`** buttons (toolbar, HUD, trainers) |
| **`PokerUi/qmldir`** | QML module registering **`components/`** and **`screens/`** types |

Bundled training JSON lives under **`poker/qml/assets/training/`** (e.g. `preflop_ranges_v1.json`, `spots_v1.json`). Assets are embedded via **`application.qrc`**.

## Game behavior (what the code does)

Blinds (including **heads-up**), **clockwise** button rotation and action/deal order (see `game-in-code.md`), burns, NL betting, showdown and **side-pot** payouts, **HUD total pot only**, stake cap, bankroll/rebuy, and what is **not** implemented are summarized in **[game-in-code.md](game-in-code.md)**.

## Tests

- **`poker/poker/tests/test_*.cpp`** — **Boost.Test** (`Test_poker`): split by area (`test_smoke_game_engine`, `test_hand_evaluation`, `test_persistence_sqlite`, etc.); see `poker/poker/tests/CMakeLists.txt` and the Tests section in the repo **`README.md`**.
- **`poker/poker/tests/CMakeLists.txt`** registers **`poker.smoke`** via **`add_test`** when **`BUILD_TESTING`** is on.

The **`poker`** library links **Qt::Qml** so MOC’d types used from tests stay consistent with the app’s Qt linkage.
