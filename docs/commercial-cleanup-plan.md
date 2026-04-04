# Texas Hold'em Gym — Commercial Cleanup & Architecture Plan

**Created:** 2026-04-04
**Goal:** Transform the current prototype into a maintainable, testable, shippable commercial product.

---

## Executive Summary

The app works end-to-end but has accumulated architectural debt that blocks commercial development:

1. **Persistence is broken** — JSON serialization doesn't round-trip scalars; the `game` god object mixes persistence with engine logic; startup ordering causes data loss.
2. **`game` is a ~2700-line god object** — table engine, bots, UI sync, persistence, bankroll, timers, and human I/O all in one class.
3. **Main-thread blocking** — nested `QEventLoop::exec()` and busy-wait `processEvents` loops for human decisions and bot pauses.
4. **No CI/CD** — no pipeline, no automated QML tests, no integration tests.
5. **Documentation drift** — docs describe QSettings-only persistence; code uses SQLite.
6. **Missing product features** — roadmap items (GTO bot, turn/river trainers, range viewer, daily challenge) not started.

The plan below is organized into **7 phases**, each with **self-contained prompts** that a coding agent can execute independently. Phases are ordered by dependency and risk.

---

## Phase 0: Stabilize Persistence (CRITICAL — do first)

**Why:** Data loss on every restart blocks all other work. Nothing else matters if user state doesn't survive.

### Task 0.1: Fix `variantToJson` / `jsonToVariant` round-trip

**Status:** In progress on `persistance` branch — recent fixes address scalar JSON parsing and QString-as-number bugs.

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/persist_sqlite.cpp, write a
self-contained test function `bool testJsonRoundTrip()` that is called from
`AppStateSqlite::init()` in debug builds only (guard with `#ifndef NDEBUG`).

It must verify that `variantToJson` → `jsonToVariant` round-trips correctly for
ALL these QVariant types:
- int (0, 1, -1, 100, INT_MAX)
- double (0.0, 1.5, -3.14, NaN, Inf)
- bool (true, false)
- QString (empty "", "hello", "AA AKs", "v1/seat0/rangeText")
- QVariantList (empty, [1,2,3], [[100,200],[300,400]])
- QVariantMap (empty, {"key": "value"})

For each case: serialize with variantToJson, parse back with jsonToVariant,
assert the result matches the original (for NaN/Inf, assert it becomes 0).
Log failures with qWarning. Return false if any fail.

Also fix any bugs this test reveals in variantToJson or jsonToVariant.
Build and run Test_poker to verify nothing breaks.
```

### Task 0.2: Eliminate startup data clobbering

**Prompt:**
```
In /home/max-gloom/sources/poker, audit the COMPLETE startup sequence for
persistence overwrites:

1. Read main.cpp lines 56-62 (loadPersistedSettings + seed logic)
2. Read game.cpp loadPersistedSettings() completely
3. Read game.cpp savePersistedSettings() / writePersistedSettingsImpl() completely
4. Read game.cpp complete_hand_idle() — it calls savePersistedSettings()
5. Read main.cpp lines 112-123 — QTimer::singleShot(400) calls beginNewHand()

Trace the EXACT sequence: init → load → seed → setRootObject → beginNewHand →
start → ... → complete_hand_idle → savePersistedSettings.

Identify: does the first hand complete and save BEFORE the user has done
anything? If so, does that save overwrite bankroll/wallet data from the DB
with fresh-game defaults?

Fix: ensure beginNewHand()/complete_hand_idle()/savePersistedSettings() do NOT
run until loadPersistedSettings() has fully completed AND the loaded data is
in memory. If the first auto-hand completes before the user acts, bankroll
must reflect loaded state, not constructor defaults.

Build and run Test_poker. Delete the SQLite DB, run the app, play 3 hands,
quit, restart — verify DB values survive.
```

### Task 0.3: Add `v1/training/*` null value cleanup

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/training_store.cpp, the functions
setTrainerAutoAdvanceMs() and setTrainerDecisionSeconds() write their value
when it differs from current. But on a fresh DB or after resetProgress(),
the stored value may be JSON "null" (from a previous bug).

Fix: In TrainingStore constructor or in a static init method called from main,
check if v1/training/trainerAutoAdvanceMs or trainerDecisionSeconds contain
null/invalid values and replace them with defaults (5000ms and 20s respectively).

Also in persist_sqlite.cpp, add a one-time migration in init(): after
migrateFromQSettingsIfEmpty(), scan all keys in the kv table. For any row
where v = 'null' (the literal string), delete that row. Log the count of
cleaned rows. This ensures old null rows don't poison future contains() checks.

Build and run Test_poker.
```

---

## Phase 1: Break Up the God Object (`game`)

**Why:** `game.cpp` is ~2700 lines with 6+ responsibilities. It's untestable, unreadable, and every change risks breaking something unrelated.

### Task 1.1: Extract `GamePersistence` — settings load/save

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/, create two new files:
game_persistence.hpp and game_persistence.cpp.

Extract from game.cpp/game.hpp:
- loadPersistedSettings()
- savePersistedSettings() / seedMissingPersistedSettings() / writePersistedSettingsImpl()
- save_bankroll_session_to_settings()
- load_bankroll_session_from_settings()
- configureImpl() (the persistence-aware configure)

Create class GamePersistence that takes a reference to game's state (or the
game object itself via a minimal interface/struct of references to the fields
it needs: small_blind, big_blind, street_bet_, starting_stack_, seat_buy_in_,
seat_wallet_, seat_cfg_, seat_participating_, bankroll_history_,
bankroll_snapshot_times_ms_, session_baseline_, human_sitting_out_,
interactive_human_, bot_slow_actions_).

GamePersistence should NOT inherit from QObject. It is a plain C++ class.

game.hpp should have a GamePersistence member. The public methods
loadPersistedSettings / savePersistedSettings just delegate.

Update CMakeLists.txt to add the new files.
Build and run Test_poker — all 31 tests must pass.
```

### Task 1.2: Extract `BankrollTracker` — history, snapshots, baselines

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/, create bankroll_tracker.hpp
and bankroll_tracker.cpp.

Extract from game.cpp/game.hpp:
- bankroll_history_ (vector of arrays)
- bankroll_snapshot_times_ms_
- session_baseline_
- record_bankroll_snapshot()
- init_bankroll_after_configure()
- All the bankrollSeries/bankrollSnapshotCount/bankrollSnapshotTimesMs accessors
- seatRankings() — it reads bankroll state
- notifySessionStatsChanged()
- stats_seq_ and the sessionStatsChanged signal

BankrollTracker should be a QObject (it emits sessionStatsChanged).
game should own a BankrollTracker member and delegate bankroll calls to it.

Expose BankrollTracker to QML either through game (preferred: Q_PROPERTY)
or as a separate context property.

Update game.hpp, game.cpp, game_ui_sync.cpp, CMakeLists.txt.
Build and run Test_poker — all 31 tests must pass.
```

### Task 1.3: Extract `HumanDecisionController` — timers, event loops

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/, create
human_decision_controller.hpp and human_decision_controller.cpp.

Extract from game.cpp/game.hpp:
- human_decision_tick_ and human_decision_deadline_ (QTimers)
- arm_decision_timers()
- requestMoreTime()
- wait_for_human_need() / wait_for_human_check_or_bet() / wait_for_human_bb_preflop()
- finish_human_check() / finish_human_bb_preflop()
- All the waiting_for_human_* / human_facing_* state variables
- submitFacingAction / submitCheckOrBet / submitBbPreflopRaise / submitFoldFromCheck

HumanDecisionController should be a QObject.
game should own it and connect its signals to drive the hand forward.

IMPORTANT: Do NOT change the nested QEventLoop pattern in this task. That is
Phase 2 work. Just move the code as-is.

Update CMakeLists.txt. Build and run Test_poker — all 31 tests must pass.
```

### Task 1.4: Extract `SeatManager` — buy-in, wallet, participation

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/, create seat_manager.hpp
and seat_manager.cpp.

Extract from game.cpp/game.hpp:
- seat_buy_in_, seat_wallet_, seat_participating_, pending_bankroll_total_
- pending_seat_buyins_apply_
- apply_seat_buy_ins_to_table()
- init_bankroll_after_configure() call coordination
- setSeatBuyIn / seatBuyIn / applySeatBuyInsToStacks
- seatBankrollTotal / setSeatBankrollTotal / apply_seat_bankroll_total_now
- canBuyBackIn / tryBuyBackIn / apply_buy_back_in_internal
- try_auto_rebuys_for_busted_bots
- sync_seat_buy_in_from_table_when_wallet_empty
- flush_pending_bankroll_totals / applyPendingBankrollTotals
- maxBuyInChips
- setSeatParticipating / seatParticipating

SeatManager should be a plain C++ class (not QObject) since game needs to
call it synchronously within hand logic.

Update CMakeLists.txt. Build and run Test_poker — all 31 tests must pass.
```

---

## Phase 2: Fix Main-Thread Blocking

**Why:** Nested `QEventLoop::exec()` and busy-wait `processEvents` loops block the UI thread and risk reentrancy bugs. This is the #1 technical risk for crashes and hangs.

### Task 2.1: Replace bot_action_pause with QTimer

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/game.cpp, find bot_action_pause().
It currently uses a busy-wait loop:
  while (timer.elapsed() < ms) QCoreApplication::processEvents(..., 16);

Replace this with a state-machine approach:
1. After a bot makes its decision, instead of calling the next action
   synchronously, save the current state and start a QTimer::singleShot
   for the pause duration.
2. When the timer fires, resume the hand from where it left off.

This requires changing run_street_betting (or its callers) from a synchronous
loop to an async state machine. The key insight: instead of
  for each seat: decide → pause → apply
it should be:
  decide → save state → timer → on timeout: apply → next seat or next street

If this is too large a refactor for one task, an acceptable intermediate step
is to replace the processEvents loop with QThread::msleep() on a worker thread
and use signals to push results back. Document which approach you chose and why.

Build and run Test_poker. Test with bot_action_delay_enabled_ = true to verify
bot actions still have visible pauses in the UI.
```

### Task 2.2: Replace nested QEventLoop with signals/slots for human decisions

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/game.cpp, the functions
wait_for_human_need(), wait_for_human_check_or_bet(), and
wait_for_human_bb_preflop() use QEventLoop::exec() to block until the
human submits an action.

This is a reentrancy risk and prevents proper async architecture.

Refactor to a state-machine pattern:
1. When the hand reaches a human decision point, save the hand state
   (street, action context, pot, etc.) and return from the current function.
2. The submit* functions (submitFacingAction, submitCheckOrBet, etc.)
   should resume the hand from the saved state.
3. The hand progression (streets, actions) becomes event-driven rather
   than a synchronous loop.

This is a significant refactor. Start by:
- Adding an enum HandPhase { Idle, WaitingForHuman, BotActing, ... }
- Adding a method resumeHand() that continues from the saved phase
- Converting one wait function at a time, starting with wait_for_human_need

Build and run Test_poker after each conversion. All 31 tests must pass.
The human HUD must still work: fold/call/raise buttons must trigger the
correct hand continuation.
```

---

## Phase 3: Testing Infrastructure

**Why:** 31 smoke tests are not enough for a commercial product. Need comprehensive unit tests, integration tests, and QML test stubs.

### Task 3.1: Add persistence round-trip tests

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/tests/test.cpp, add a new
test suite PERSIST_SUITE with these cases:

1. test_variant_to_json_int: variantToJson(QVariant(42)) → "42", round-trip
2. test_variant_to_json_double: variantToJson(QVariant(3.14)) → number, round-trip
3. test_variant_to_json_bool: true/false round-trip
4. test_variant_to_json_string: empty string, "AA AKs QQ+", round-trip
5. test_variant_to_json_list: QVariantList with ints, nested lists
6. test_variant_to_json_null: invalid QVariant → "null", does not round-trip
7. test_variant_to_json_nan: NaN → "0", loads as 0
8. test_variant_to_json_string_not_number: ensure "" doesn't become 0

These tests should NOT require SQLite or file I/O — test the functions directly.
Make jsonToVariant and variantToJson accessible from tests (either make them
non-static, add a test header, or link the functions).

Build and run Test_poker — all old + new tests must pass.
```

### Task 3.2: Add bankroll persistence integration test

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/tests/test.cpp, add a test:

test_bankroll_survives_save_load:
1. Create a game instance
2. Set blinds to 1/2, stack 100
3. Record 5 bankroll snapshots with known values
4. Initialize AppStateSqlite with a temp file (use mktemp or similar)
5. Call savePersistedSettings()
6. Create a NEW game instance
7. Call loadPersistedSettings()
8. Verify bankroll_history has the same 5 snapshots
9. Verify session_baseline matches
10. Clean up temp file

This tests the full save → load cycle for bankroll data.
Build and run Test_poker.
```

### Task 3.3: Add bot decision coverage tests

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/poker/tests/test.cpp, add test suite
BOT_DECISION_SUITE:

1. test_always_call_never_folds: AlwaysCall bot, facing a raise, always continues
2. test_rock_folds_weak_hands: Rock bot, weak hand, high fold probability
3. test_gto_heuristic_uses_range: GTOHeuristic with a tight range, verifies
   that hands outside the range fold more often
4. test_bot_preflop_continue_probability: verify bot_preflop_continue_p returns
   values in [0,1] for various inputs
5. test_bot_postflop_continue_probability: same for postflop
6. test_fill_preset_range: each BotStrategy fills a non-empty range

These should test the bot.cpp functions directly, not through game.
Build and run Test_poker.
```

---

## Phase 4: Documentation Reconciliation

**Why:** Docs say QSettings, code uses SQLite. Strategy names in QML don't match C++ enum. Architecture doc is outdated.

### Task 4.1: Update architecture.md

**Prompt:**
```
In /home/max-gloom/sources/poker/docs/architecture.md, update the document
to reflect the current state of the codebase:

1. Replace all references to "QSettings" persistence with the current
   AppStateSqlite system (SQLite primary, QSettings INI fallback).
2. Add a "Persistence" section describing:
   - SQLite KV store at AppLocalDataLocation/texas-holdem-gym.sqlite
   - TEXAS_HOLDEM_GYM_SQLITE env override
   - Key naming convention (v1/*)
   - JSON serialization format
   - QSettings fallback behavior
3. Update the module table to include persist_sqlite, training_store,
   training_controller, session_store
4. Add a "Data flow" section: startup sequence (init → load → seed → QML → hand)
5. Remove the statement "no SQL database"
6. Keep the document concise — max 150 lines

Do NOT change any code files. Only update docs/architecture.md.
```

### Task 4.2: Update README.md persistence section

**Prompt:**
```
In /home/max-gloom/sources/poker/README.md, update the "Saved configuration"
paragraph (around line 68) to describe:

1. Primary: SQLite database at ~/.local/share/TexasHoldemGym/Texas Hold'em Gym/texas-holdem-gym.sqlite
2. Override: TEXAS_HOLDEM_GYM_SQLITE environment variable
3. Fallback: QSettings INI at ~/.config/TexasHoldemGym/ if SQLite fails
4. Migration: first run migrates legacy QSettings into SQLite automatically

Keep the paragraph concise (4-6 sentences). Do NOT change any code.
```

### Task 4.3: Sync strategy names between QML and C++

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/qml/screens/SetupScreen.qml, the
strategyNames property (around line 111) is a hardcoded JavaScript array
that must match the C++ BotStrategy enum order in bot.hpp.

Fix: Instead of hardcoding, add a Q_INVOKABLE QStringList strategyNames()
method to game.hpp/game.cpp that returns the display names from C++.
Use strategy_description() or a new function that returns just the short name.

In SetupScreen.qml, replace the hardcoded array with:
  readonly property var strategyNames: pokerGame.strategyNames()

This ensures the list can never drift from the C++ enum.

Update game.hpp, game.cpp, SetupScreen.qml. Build and run Test_poker.
```

---

## Phase 5: CI/CD Pipeline

**Why:** No automated build/test means regressions go unnoticed. Commercial products need CI.

### Task 5.1: Create GitHub Actions CI

**Prompt:**
```
Create .github/workflows/ci.yml in /home/max-gloom/sources/poker/ with:

name: CI
on: [push, pull_request]

jobs:
  build-linux:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Install Qt 6
        uses: jurplel/install-qt-action@v4
        with:
          version: '6.10.0'
          modules: 'qtbase qtdeclarative'
      - name: Install deps
        run: |
          sudo apt-get update
          sudo apt-get install -y libboost-test-dev libsqlite3-dev ninja-build
      - name: Configure
        run: cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
      - name: Build
        run: cmake --build build -j$(nproc)
      - name: Test
        run: ctest --test-dir build --output-on-failure

Verify the workflow syntax is valid YAML. Do not run it — just create the file.
```

### Task 5.2: Add clang-format configuration

**Prompt:**
```
Create .clang-format in /home/max-gloom/sources/poker/ with a style that
matches the existing code conventions observed in the repo:

- 4-space indent (no tabs)
- Braces on same line for control structures
- Column limit 120
- East const (const after type) — match existing style
- C++17 standard

Base on LLVM style with appropriate overrides.

Do NOT reformat existing code — just create the config file so new code
can be formatted consistently.
```

---

## Phase 6: Product Feature Completion

**Why:** Roadmap features (range viewer, turn/river trainers, GTO bot) are the commercial differentiators.

### Task 6.1: Range Viewer screen

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/qml/screens/, create RangeViewer.qml.

This is a READ-ONLY reference screen showing opening ranges by position.
It should:
1. Load preflop_ranges_v1.json from training assets
2. Show a position selector (UTG, HJ, CO, BTN, SB)
3. Display the 13x13 range grid (reuse RangeGrid.qml in read-only mode)
4. Color-code by action: green=raise, blue=call, red=fold
5. Show action frequencies on hover/tap
6. Use ThemedPanel and match existing app styling

Add navigation from Main.qml StackLayout (new index) and from TrainerHome.qml
and LobbyScreen.qml.

Register in application.qrc. Build and verify the app launches.
```

### Task 6.2: Enable preflop trainer vs3bet/3bet modes

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/qml/screens/PreflopTrainer.qml,
the mode dropdown (around the combo box for drill mode) only shows ["open"]
and is disabled.

1. Read training_controller.cpp to understand what modes are supported
2. Read preflop_ranges_v1.json to see what scenario keys exist
3. Enable the mode dropdown
4. Add "vs3bet" and "3bet" options if the JSON data supports them
5. If JSON data doesn't exist for those modes yet, create stub entries
   in preflop_ranges_v1.json with reasonable ranges for 100bb cash

Build and verify the trainer works in each mode.
```

### Task 6.3: Turn/River trainer foundation

**Prompt:**
```
In /home/max-gloom/sources/poker/, plan and implement the foundation for
turn and river trainers:

1. In training_controller.hpp/cpp, add:
   - startTurnDrill(QString matchup)
   - nextTurnQuestion() / submitTurnAnswer(QString action)
   - Same for river

2. Create spots_turn_v1.json and spots_river_v1.json with 3-5 spots each
   for SRP BTN vs BB:
   - Turn: common turn cards on representative flop textures
   - River: common river completions
   - Actions: check, bet 33%, bet 75%
   - Include frequencies and EV values

3. Create TurnTrainer.qml and RiverTrainer.qml (can share most layout
   with FlopTrainer.qml — consider extracting a shared SpotTrainer component)

4. Add navigation from TrainerHome.qml and Main.qml

Build and verify basic drill flow works for turn and river.
```

---

## Phase 7: Polish for Release

### Task 7.1: Error handling and user feedback

**Prompt:**
```
Audit all QML screens in /home/max-gloom/sources/poker/poker/qml/ for
missing error handling:

1. SolverScreen: what happens if equity computation fails?
2. Trainers: what if JSON asset fails to load?
3. SetupScreen: what if savePersistedSettings silently fails?
4. StatsScreen: what if bankroll data is corrupted?

For each case:
- Add a visible error message (use a Popup or inline Label)
- Log the error with qWarning
- Ensure the app doesn't crash or hang

Build and verify each error path by temporarily corrupting data.
```

### Task 7.2: Performance audit

**Prompt:**
```
In /home/max-gloom/sources/poker/, audit performance:

1. equity_engine.cpp: Monte Carlo loop — is it efficient?
   - Check for unnecessary allocations in the hot loop
   - Verify deck shuffling is O(n) Fisher-Yates
   
2. persist_sqlite.cpp: savePersistedSettings writes ~100 keys on every
   hand completion. Check if this should use a transaction (BEGIN/COMMIT)
   for atomicity and performance.

3. game_ui_sync.cpp: sync_ui pushes many properties. Check if unnecessary
   syncs happen (e.g. syncing 6 seats when only 1 changed).

4. RangeGrid.qml: 169-cell grid. Check if it uses efficient delegates
   or creates/destroys 169 items on every refresh.

For each finding: fix if the fix is straightforward, or document the issue
with a TODO comment including expected impact.

Build and run Test_poker.
```

### Task 7.3: Packaging and distribution

**Prompt:**
```
In /home/max-gloom/sources/poker/poker/packaging/:

1. Audit install-local.sh and bundle-poker-app.inc.sh:
   - Do they correctly bundle SQLite3?
   - Do they set RUNPATH correctly?
   - Test by running install-local.sh and launching from the install location

2. Create an AppImage build script (packaging/linux/build-appimage.sh):
   - Use linuxdeploy or appimagetool
   - Include the .desktop file and icon
   - Bundle all Qt deps and SQLite
   - Output: Texas_Holdem_Gym-x86_64.AppImage

3. Create packaging/linux/flatpak/io.github.texasholdemgym.yaml (manifest stub)
   for future Flatpak distribution

Build and test the AppImage on a clean system if possible.
```

---

## Execution Order & Dependencies

```
Phase 0 (Persistence) ──→ Phase 1 (God Object) ──→ Phase 2 (Async)
         │                                                │
         └──→ Phase 3 (Tests) ←──────────────────────────┘
                    │
         Phase 4 (Docs) ──→ Phase 5 (CI/CD)
                    │
         Phase 6 (Features) ──→ Phase 7 (Polish)
```

- **Phase 0** is prerequisite for everything (data integrity).
- **Phase 1** can start after Phase 0 is stable.
- **Phase 2** depends on Phase 1 (refactoring async is easier after extraction).
- **Phase 3** can run in parallel with Phase 1-2 (test existing behavior first).
- **Phase 4-5** are independent and can run anytime.
- **Phase 6** should wait for Phase 0-1 to avoid merge conflicts with the god object.
- **Phase 7** is final polish before release.

---

## Model Selection Guide

| Task Type | Recommended Model | Reasoning |
|-----------|-------------------|-----------|
| Phase 0 (persistence bugs) | Capable model | Subtle serialization bugs need deep reasoning |
| Phase 1 (extract classes) | Fast model | Mechanical refactoring, well-defined inputs/outputs |
| Phase 2 (async refactor) | Capable model | Architecture change, reentrancy risks |
| Phase 3 (write tests) | Fast model | Straightforward test writing |
| Phase 4 (docs) | Fast model | Text editing |
| Phase 5 (CI) | Fast model | YAML config |
| Phase 6 (features) | Capable model | New feature design and implementation |
| Phase 7 (polish) | Fast model for audit, capable for fixes | Mixed |

---

## Success Criteria

After all phases:

1. App starts, loads ALL persisted state correctly, and survives restart
2. `game.cpp` is under 800 lines (engine only)
3. No nested QEventLoop or processEvents busy-waits
4. 80+ unit tests covering persistence, bots, bankroll, hand eval
5. CI passes on every push
6. Docs match code
7. All roadmap V1 features (preflop/flop/turn/river trainers, range viewer) work
8. AppImage builds and runs on clean Ubuntu 24.04
