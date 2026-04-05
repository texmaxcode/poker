# Texas Hold'em Gym — engineering backlog

Prioritized ideas from code review: performance, structure, and future features. Not a release checklist.

---

## Current product surface (reference)

- **Table** — 6-max NLHE, bots, sit-out, timers, sizing presets, side pots, floating HUD beside seat 0 (`GameScreen` / `GameControls`).
- **Setup** — Bot styles, ranges, buy-in / wallet, stakes.
- **Training** — Preflop through river drill trainers, `TrainerHome`, progress in `TrainingStore`.
- **Solver & equity** — Monte Carlo equity, pot-odds / chip-EV, toy Nash helpers.
- **Stats** — Leaderboard, bankroll chart, session reset.
- **Persistence** — `AppStateSqlite` (KV in SQLite), QSettings INI fallback, migration.
- **Linux packaging** — Helper scripts and manifest under `poker/packaging/linux/` (e.g. AppImage build, Flatpak YAML, desktop file).

---

## Priority 1 — Persistence performance

SQLite writes and JSON reserialization on the main thread dominate cost during play.

- Enable **WAL** + `PRAGMA synchronous=NORMAL` after open in `persist_sqlite.cpp`.
- **Cache** prepared statements for hot `INSERT`/`SELECT` paths instead of prepare/finalize per call.
- Wrap multi-key saves in **`BEGIN`/`COMMIT`**.
- **Dirty flags** — avoid rewriting all keys when one field changed.
- **Bankroll history** — prefer append-only table over full JSON blob rewrites.
- Halve reads: drop redundant `contains()` + `value()` pairs; simplify `contains()` to `SELECT 1 … LIMIT 1`.

---

## Priority 2 — Main-thread blocking

- Replace **`bot_action_pause`** busy-wait with timer-driven bot turns.
- Split **`game::start()`** / hand flow so the UI thread is not blocked for whole hands (state machine + signals).
- Batch **`flush_ui()`** / `sync_ui()` where redundant.

---

## Priority 3 — `game.cpp` decomposition

- Extract **showdown / payout** logic from **`do_payouts`** into testable units.
- Extract **result / status line formatting** into dedicated helpers.
- Move bot decision branches toward **`Bot`** / **`HumanDecisionController`** ownership.

---

## Priority 4 — QML performance

- Debounce **`TableFelt`** / heavy Canvas work on resize.
- Reduce **`RangeGrid`** object count (shared `MouseArea`, optional hover off in read-only mode).
- Smarter **`sync_ui`** (per-seat dirty flags).
- Optional: move **Stats** bankroll chart paint to `QQuickPaintedItem` or shared script.

---

## Priority 5 — Trainer / range UI

- Shared base for **Flop / Turn / River** trainer screens (mostly duplicate structure).
- Deduplicate **RangeViewer** / **RangeGrid** tooltip helpers.

---

## Priority 6 — Future features (not implemented)

- Play vs **pre-solved GTO** bot + post-hand EV review.
- **Mistake dashboard** over `TrainingStore` aggregates.
- **Daily challenge** / light progression.
- **Hand history** review screen.

---

## Priority 7 — Tests

Expand beyond current Boost.Test suites: persistence edge cases, training score boundaries, human timeout paths, multi-way side pots, bankroll trim logic.
