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
│       ├── hand_log_store / hand_history_query (SQLite hand log)   │
│       └── persist_sqlite (AppStateSqlite: kv + hand schema)       │
└─────────────────────────────────────────────────────────────────┘
```

## Application shell

- **`poker/main.cpp`** sets `QCoreApplication` organization/name (used by the INI fallback), calls **`AppStateSqlite::init()`**, creates **`game`**, **`loadPersistedSettings()`**, optionally **`seedMissingPersistedSettings()`** when the store is open but core keys are absent, then **`PokerSolver`**, **`ToyNashSolver`**, **`TrainingStore`**, **`TrainingController`**, **`SessionStore`**, **`HandHistoryQuery`**, and exposes **`pokerGame`**, **`pokerSolver`**, **`toyNashSolver`**, **`sessionStore`**, **`trainingStore`**, **`trainer`**, **`handHistory`**, plus bundled-font family strings to QML: **`appFontFamily`** (Merriweather — UI body), **`appFontFamilyDisplay`** (Rye — titles), **`appFontFamilyButton`** (Holtwood One SC — buttons / seat names), **`appFontFamilyMono`** (Roboto Mono — stacks, pot, sliders). Fonts are loaded from **`application.qrc`** via `QFontDatabase::addApplicationFont`; the app default `QFont` uses the UI family. **`aboutToQuit`** calls **`savePersistedSettings()`** on the game.
- The UI entry is **`qrc:/Main.qml`**: an `ApplicationWindow` with a **stack** of pages (lobby, table, bot/range setup, solver/equity, bankroll/stats, **hand history**, training hub, preflop–river trainers, range viewer). **`Metrics.qml`** defines **`windowMinWidth` / `windowMinHeight`** (currently **1280×720**), default window size, and toolbar/HUD geometry tokens; the window applies those as **`minimumWidth` / `minimumHeight`**. Fonts and the header/toolbar live on the window; **`Theme.qml`** maps the four `appFontFamily*` context properties to **`fontFamilyUi`**, **`fontFamilyDisplay`**, **`fontFamilyButton`**, **`fontFamilyMono`** plus colors, spacing, and trainer/table tokens.

## UI layout and styling (QML)

- **`Theme/Theme.qml`** (singleton) — palette, semantic text colors, **`compactUiScale(shortSide)`** for scroll pages, trainer typography tokens, card sizes, range-grid colors, section title color.
- **`theme/Metrics.qml`** (singleton) — window chrome dimensions, HUD button heights, minimum window size (see above).
- **`BrandedBackground.qml`** — full-page charcoal/burgundy **gradient** + light **film grain** (`Canvas`).
- **`ThemedPanel.qml`** — framed panels with **uppercase** section titles in **`Theme.fontFamilyDisplay`** (Rye).
- **Lobby** — **`LobbyScreen.qml`**: logo + **`ThemedPanel`** with **six nav tiles in one row** (banner art + subtitle); content width is capped by **`Theme.trainerContentMaxWidth`** with side gutters.
- **Table** — **`GameScreen.qml`**: six **`Player`** seats on an oval; **`GameControls`** uses **`embeddedMode: !hudBottomDock`**. By default **`hudBottomDock`** is **false**, so the HUD is a floating panel beside **seat 0** (`panelWidth` from **`tableArea.hudPanelW`**, position from **`floatHudX` / `floatHudY`**, **`hudStacked`** when narrow). If **`hudBottomDock`** is **true**, the HUD spans the bottom of the table area. **`tableArea.tableScale`** shrinks the felt and seats on short viewports.
- **Buttons** — **`GameButton.qml`** implements HUD, toolbar chrome, form, and chip styles; standard **`Button`** / **`TabBar`** in setup/solver/stats use **`Theme.fontFamilyButton`** where styled explicitly. **`SizingPresetBar`** preset chips use the button font.
- **Trainer / solver / stats** — scroll views with **`ThemedPanel`** sections; solver and setup use **`GridLayout`** / forms; stats use **`ThemedPanel`** + tables and a **Canvas** bankroll chart.
- After **`QQmlApplicationEngine::load()`**, a short **`QTimer::singleShot`** finds the table **`Page`** by **`objectName: "game_screen"`**, calls **`game::setRootObject()`** on it, then **`beginNewHand()`** so the first hand starts only when the table is ready. The engine does **not** use `Game.qml` as the root object.

## Persistence

- **`AppStateSqlite`** (`persist_sqlite.*`) opens a single SQLite file (or **`QSettings`** INI fallback). Default path: **`AppLocalDataLocation/texas-holdem-gym.sqlite`**.
- Set **`TEXAS_HOLDEM_GYM_SQLITE`** to an absolute path to override the database location (tests and debugging).
- **Key–value settings** live in table **`kv`**: **`k`** is a dotted key (`v1/smallBlind`, `v1/seat0/strategy`, `v1/training/…`), **`v`** is **JSON text**. Hot-path reads/writes reuse **long-lived `sqlite3_stmt`** instances (`SELECT v`, `SELECT 1` for existence-only **`contains`**, `INSERT OR REPLACE`). Bulk deletes use **`removeKeysWithPrefix`** (e.g. `v1/training/`).
- **Hand log (relational)** — when SQLite is active, schema version **`PRAGMA user_version = 1`** adds **`players`**, **`hands`**, and **`actions`** (integer-heavy schema; WAL + tuning PRAGMAs applied at open). Rows are written in batches via **`HandLogBatch`** (`hand_log_store.*`) from **`game`** at end-of-hand; QML reads through **`HandHistoryQuery`** (`hand_history_query.*`, context property **`handHistory`**). The INI fallback has **no** hand-log tables.
- For **offline analytics** (Parquet, pandas, DuckDB), see **[sqlite-parquet-python.md](sqlite-parquet-python.md)**.

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
| **`persist_sqlite.*`** | **`AppStateSqlite`**: SQLite **`kv`** (JSON values), hand-log DDL, INI fallback, migration from legacy QSettings |
| **`hand_log_store.*`** | **`HandLogBatch`**: transactional batched inserts into **`hands` / `actions` / `players`** |
| **`hand_history_query.*`** | **`HandHistoryQuery`**: QML read API over the hand-log tables |
| **`cards.*`** | Ranks, suits, deck; compact string form + **`card_to_qml_asset_path`** for SVG resource names |
| **`player.*`** | Hole cards, stack, **`pay`** / **`take_from_stack`** (clamped) |
| **`hand_eval.*`** | Best 5 of 7, comparison, human-readable descriptions (order-invariant best-of-seven) |
| **`holdem_side_pot.*`** | Table-stakes **main + side pot** slices — `do_payouts` |
| **`game.*` / `game_payouts.cpp` / `game_ui_sync.cpp`** | Table vector, button, blinds, streets, **`in_hand`**, betting loop, bots, **`do_payouts`** (payout TU), persistence via **`AppStateSqlite`**, QML API; **`sync_ui`** / **`flush_ui`** |
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
| **`Main.qml`** | Shell: navigation; context **`pokerGame`**, **`pokerSolver`**, **`trainer`**, **`handHistory`**, … |
| **`screens/LobbyScreen.qml`** | Entry: logo + single-row nav tiles (table, setup, solver, drills, stats, hand history) |
| **`screens/GameScreen.qml`** | Table layout, **`game_screen`**, **`Player`** delegates, floating **`GameControls`** beside seat 0 |
| **`components/GameControls.qml`**, **`components/SizingPresetBar.qml`** | Fold / call / raise / check / bet, timers, sit-out; Min / ⅓ / ½ / ⅔ / Pot / All presets |
| **`components/Table.qml`** | Pot HUD (with call amount), community board cards |
| **`screens/SetupScreen.qml`**, **`screens/SolverScreen.qml`** | Ranges, strategies, solver/equity UI |
| **`screens/StatsScreen.qml`** | Bankroll tables, leaderboard, chart |
| **`screens/HandHistoryScreen.qml`** | List/detail for logged **`hands`** / **`actions`** |
| **`screens/TrainerHome.qml`**, **`PreflopTrainer.qml`**, **`FlopTrainer.qml`** | Training hub and drills |
| **`components/GameButton.qml`** | Shared **`hud` / `chrome` / `form` / `chip`** buttons (toolbar, HUD, trainers) |
| **`PokerUi/qmldir`** | QML module registering **`components/`** and **`screens/`** types |

Bundled training JSON lives under **`poker/qml/assets/training/`** (e.g. `preflop_ranges_v1.json`, `spots_v1.json`). Fonts and images are embedded via **`application.qrc`** (~30 QML files under **`poker/qml/`** plus **`Main.qml`**).

## Game behavior (what the code does)

Blinds (including **heads-up**), **clockwise** button rotation and action/deal order (see `game-in-code.md`), burns, NL betting, showdown and **side-pot** payouts, **HUD total pot only**, stake cap, bankroll/rebuy, and what is **not** implemented are summarized in **[game-in-code.md](game-in-code.md)**.

## Larger refactors (not scheduled here)

These need product/architecture decisions or multi-week effort: **async / state-machine** hand runner so `game::start()` does not block the UI thread; **partial `kv` saves** (dirty keys) to shrink write amplification; **bankroll history** as an append-only table instead of one JSON blob per snapshot; **per-seat dirty flags** in `sync_ui`; **shared QML base** for flop/turn/river trainers; **RangeGrid** input consolidation; **pre-solved GTO** import path; **training mistake dashboards**; **daily-challenge** style progression.

## Recently landed (engineering)

- **`AppStateSqlite`**: prepared statements for **`kv`** access; **`contains()`** uses **`SELECT 1`** (row existence only).
- **`game_payouts.cpp`**: houses **`game::do_payouts`**.
- **`TableFelt.qml`**: debounced **Canvas** grain repaint on resize.
- **`test_training_store.cpp`**: clamps on trainer timing settings.

## Tests

- **`poker/poker/tests/test_*.cpp`** — **Boost.Test** (`Test_poker`): split by area (`test_smoke_game_engine`, `test_hand_evaluation`, `test_persistence_sqlite`, etc.); see `poker/poker/tests/CMakeLists.txt` and the Tests section in the repo **`README.md`**.
- **`poker/poker/tests/CMakeLists.txt`** registers **`poker.unit`** via **`add_test`** when **`BUILD_TESTING`** is on.

The **`poker`** library links **Qt::Qml** so MOC’d types used from tests stay consistent with the app’s Qt linkage.
