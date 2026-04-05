# Texas Hold'em Gym — Next Steps

**Created:** 2026-04-04
**Scope:** Engineering roadmap from current state to shippable product.

---

## Current state

The app is feature-complete for its V1 surface area:

- **Table play** — 6-max NLHE with configurable blinds/stacks, human vs 5 bots, sit-out, timed decisions, bet-sizing presets, side pots, showdown; **HUD** floats beside seat 0 (Merriweather / Holtwood / Rye / Roboto Mono via bundled fonts).
- **Window** — Minimum size enforced in QML **`Metrics.qml`** (**1280×720**); default size **1400×900**.
- **Bot configuration** — Per-seat strategy archetypes, editable 13×13 opening ranges, per-seat buy-in/wallet; stakes row with **Apply stakes** adjacent to SB/BB/Min raise controls.
- **Training** — Preflop, flop, turn, and river drill trainers with grading, EV feedback, progress stats.
- **Solver & equity** — Monte Carlo equity vs range or exact hand, pot-odds/chip-EV, Kuhn/Leduc Nash (CFR+).
- **Range viewer** — Read-only reference screen with position/mode selectors and composite range grid.
- **Stats** — Leaderboard, bankroll-over-time chart, session resets.
- **Persistence** — SQLite KV store (QSettings INI fallback), auto-migration from legacy format.
- **Packaging** — AppImage, Flatpak stub, install scripts, `.desktop` file.
- **CI** — GitHub Actions build + test on push/PR.

### What was just cleaned up

- Deleted `holdem_rules_facade.hpp` (entirely unused facade).
- Removed dead methods: `board_line_for_ui`, `hand_result_status_line`, `push_human_action_status` (no-op called 20+ times).
- Removed dead members: `river_last_aggressor_`, `river_had_bet_or_raise_` (written, never read).
- Removed dead sync methods: `PokerSolver::computeEquity`, `ToyNashSolver::solveKuhn` (only async variants are used from QML).
- Removed `PokerSolver::equityComputationRunning` (never called).
- Removed `TrainingController::lastFeedback` getter and `lastFeedbackChanged` signal (never connected from QML).
- Removed unnecessary includes: `<string>` from `utils.hpp`, `<cmath>` from `poker_solver.cpp`, `<random>` and `<cmath>` from `toy_nash_solver.cpp`.
- Removed 21 dead Theme.qml properties, 3 dead Fonts.qml properties, 2 dead Metrics.qml properties.
- Deleted outdated docs: `commercial-cleanup-plan.md` (all phases executed), `mvp-trainer-roadmap.md` (implemented + stale QSettings references).
- Fixed QSettings reference in `game-in-code.md`.
- Updated `architecture.md` to remove `holdem_rules_facade.hpp` row.

---

## Priority 1 — Persistence performance (high impact, moderate effort)

The persistence layer is the biggest performance bottleneck. A full hand triggers ~50 key-value writes, full bankroll history re-serialization, and multiple fsyncs — all on the main thread.

### 1.1 Enable WAL mode and PRAGMA tuning

Add after `sqlite3_open_v2` succeeds in `persist_sqlite.cpp`:
```cpp
sqlite3_exec(g_db, "PRAGMA journal_mode=WAL", nullptr, nullptr, nullptr);
sqlite3_exec(g_db, "PRAGMA synchronous=NORMAL", nullptr, nullptr, nullptr);
```
WAL eliminates reader–writer contention and coalesces syncs. `synchronous=NORMAL` under WAL only risks data loss on a process crash during checkpoint — acceptable for a game.

### 1.2 Cache prepared statements

`setValue`, `value`, and `contains` each compile a fresh `sqlite3_prepare_v2` on every call. With ~50 writes per save, that's 50 prepare+finalize cycles for the same SQL.

Cache three `sqlite3_stmt*` pointers (INSERT/REPLACE, SELECT, EXISTS) after init. Use `sqlite3_reset` + `sqlite3_clear_bindings` between calls.

### 1.3 Wrap multi-key writes in transactions

`savePersistedSettings` writes 50+ keys without a transaction — each is an implicit auto-commit. `SessionStore::saveSolverFields` writes 9 keys the same way.

Wrap in `BEGIN` / `COMMIT` to reduce fsyncs from N to 1.

### 1.4 Dirty-flag saves

`writePersistedSettingsImpl` writes **everything** (blinds, all 6 seats, ranges, bankroll history) even when only one field changed. Track dirty categories with a `std::bitset` and only write what changed.

### 1.5 Incremental bankroll storage

Bankroll history is fully re-serialized as JSON on every hand (up to 8000 snapshots × 6 players = 200–400 KB JSON). Move to a dedicated `bankroll_snapshots` SQLite table with `INSERT` per hand instead of full rewrite.

### 1.6 Eliminate double-read pattern

`loadPersistedSettings` calls `contains(key)` then `value(key)` — two SELECT queries per key. Use `value(key)` with a sentinel default and check the return, halving all read queries.

### 1.7 Fix `contains()` implementation

`contains()` currently fetches the full blob, parses JSON, and checks validity. Use `SELECT 1 FROM kv WHERE k = ? LIMIT 1` instead.

---

## Priority 2 — Main-thread blocking (high impact, high effort)

### 2.1 Replace `bot_action_pause` busy-wait

`bot_action_pause()` is a 2.4-second busy-wait spin loop (16ms sleep + processEvents). With 5 bots, a hand blocks the UI for 12+ seconds. Replace with a `QTimer::singleShot` chain or `QStateMachine` that yields control to the event loop between bot actions.

### 2.2 Make `start()` asynchronous

`game::start()` runs the entire hand (preflop through river) synchronously. Combined with `bot_action_pause`, this means the main thread is blocked for the entire hand. Break it into a state machine driven by signals/timers.

### 2.3 Reduce `flush_ui()` frequency

`flush_ui()` calls `sync_ui()` + `processEvents(100ms)` and is invoked 18+ times per hand. Many of these are redundant (e.g., before and after a bot action). Batch UI syncs per street or per action group.

---

## Priority 3 — `game.cpp` decomposition (medium impact, high effort)

`game.cpp` is ~1900 lines. Key extraction candidates:

### 3.1 Extract `ShowdownResolver`

`do_payouts` (160 lines) mixes hand comparison, side-pot splitting, stack mutation, and result formatting. Extract to a pure-logic class that takes hand data and returns `{seat → chips_won, status_lines}`.

### 3.2 Extract `HandResultFormatter`

`board_compact_for_result`, `fold_win_status_line`, `winning_hand_label`, `format_showdown_payout_lines_from_gains`, `result_banner_card_assets_for_seat`, `set_hand_result_status` — all result/status formatting. Move to a dedicated formatter.

### 3.3 Move bot decisions to `Bot` class

Bot fold/call/raise logic is inlined in `handle_forced_response`, `handle_postflop_check_or_bet`, `handle_bb_preflop_option`. The `Bot` class should own the decision, not the table engine.

### 3.4 Consolidate human handling into `HumanDecisionController`

The human branch of `handle_forced_response` (~115 lines) duplicates chip-taking and label-setting logic that's also in `HumanDecisionController`. Unify so the controller owns all human action mechanics.

---

## Priority 4 — QML rendering performance (medium impact, moderate effort)

### 4.1 Debounce `TableFelt` repaint

`TableFelt.qml` paints up to 8,000 dots on every resize without debounce. `BrandedBackground` already has a 48ms debounce timer — apply the same pattern.

### 4.2 Optimize `RangeGrid` cell rendering

Each of the 169 cells creates 2–3 Rectangles + a MouseArea + a Connections block (~1,183 objects). Consider:
- Single MouseArea on the grid with coordinate math instead of 169 individual ones.
- Disable `hoverEnabled` in read-only mode where tooltips aren't needed.

### 4.3 Reduce `sync_ui` overhead

`sync_ui` rebuilds six `QVariantList` objects from scratch on every call, even when nothing changed. Add per-seat dirty tracking and skip unchanged seats.

### 4.4 Extract Canvas painting to C++ or JS module

`StatsScreen.qml` `bankCanvas.onPaint` is ~180 lines of imperative Canvas2D. Consider extracting to a `QQuickPaintedItem` subclass or a separate `.js` file for maintainability.

---

## Priority 5 — Trainer refactoring (low impact, moderate effort)

### 5.1 Extract shared trainer base component

`FlopTrainer.qml`, `TurnTrainer.qml`, and `RiverTrainer.qml` are ~95% identical. Extract the shared ~150 lines of timer/clock/drill lifecycle code into a reusable `SpotTrainerBase` component.

### 5.2 Deduplicate `RangeViewer` / `RangeGrid` tooltip logic

`RangeViewer` duplicates ~60 lines of tooltip positioning and hand notation functions from `RangeGrid`. Factor into a shared JS module or expose from `RangeGrid`.

---

## Priority 6 — New features (future roadmap)

These are features referenced in earlier planning docs that are not yet implemented:

### 6.1 Play vs GTO bot

Bot decisions driven by a pre-solved strategy database (initially SRP BTN vs BB). Post-hand review showing per-decision EV loss. Requires:
- `gto_bot_v1.json` strategy DB
- New `BotStrategy` variant that delegates to DB lookup
- Human review screen listing decisions + EV loss

### 6.2 Mistake tracker & dashboard

Aggregate leaks by position/street/spot type. Recommend targeted drills based on weakest areas. Data is already tracked in `TrainingStore`; needs a UI surface.

### 6.3 Daily challenge

Lightweight gamification: streak counters, XP, daily spot set. `TrainingStore` already has hooks for streak tracking.

### 6.4 Review screen

Post-game decision list with EV loss for each action (where DB coverage exists). Useful standalone and as the after-action report for GTO bot play.

---

## Priority 7 — Testing gaps

Current test count: 9 test files, ~31 test cases. Target: 80+.

### Missing coverage
- Persistence round-trip edge cases (nested QVariantList, empty maps, unicode keys)
- Training controller drill scoring (correct/mix/wrong threshold boundaries)
- Human decision controller timeout behavior
- Seat manager edge cases (all seats sitting out, all busted)
- Side pot with 3+ all-ins at different stack sizes
- Bankroll tracker snapshot trimming

---

## File inventory (post-cleanup)

### Docs (`docs/`)
| File | Status |
|------|--------|
| `architecture.md` | Current — architecture overview |
| `building.md` | Current — build instructions |
| `game-in-code.md` | Current — engine rules spec |
| `next-steps.md` | This document |

### C++ (`poker/poker/`)
37 source files (18 `.cpp` + 18 `.hpp` + `game_ui_sync.cpp`). `holdem_rules_facade.hpp` deleted.

### QML (`poker/qml/`)
~30 QML files: **components/** (HUD, table, range grid, themed controls), **screens/** (lobby, game, setup, solver, stats, trainers, range viewer), **Theme/** + **theme/** singletons (`Theme.qml`, `Metrics.qml`, `Fonts.qml`), **`Main.qml`**. Resources listed in `application.qrc`.

### Tests (`poker/poker/tests/`)
9 test files covering cards, deck, player, game engine, hand eval, equity, range matrix, side pots, bot decisions, persistence.
