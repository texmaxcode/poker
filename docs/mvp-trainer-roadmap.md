# Texas Hold’em Gym — MVP Trainer Roadmap (Implementation Doc)

**Status (repo):** Preflop and flop drill flows, bundled JSON strategies, `TrainingStore` / `TrainingController`, `TrainerHome`, `PreflopTrainer`, and `FlopTrainer` are **implemented**. Training progress appears on **Trainer home** and **Bankroll & stats**. Items below that are still **not** in-tree include **play vs GTO bot**, **range viewer** as a dedicated surface, **turn/river** trainers, and **daily challenge** — treat the rest of this doc as a mix of shipped behavior and future ideas unless a section says otherwise.

This document translates the **MVP Feature List** into concrete engineering changes for the current codebase (Qt Quick QML UI + C++ engine).

## Goals (V1)

- **Preflop trainer**: position-based ranges (100bb cash), immediate feedback, mistake tracking.
- **Postflop spot trainer**: pre-solved common spots (start with SRP BTN vs BB, flop only), action + EV + frequency feedback.
- **Play vs GTO bot**: full hands, bot decisions driven by pre-solved strategy DB, post-hand review with EV loss.
- **EV feedback system**: per decision EV, best action EV, EV loss, mix frequency, short explanation tags.
- **Mistake tracker + dashboard**: aggregate leaks by position/street/spot; recommend drills.
- **Training modes**: quick drill, timed session, daily challenge (lightweight gamification).
- **Range viewer**: grid view of opening/3-bet/call ranges by position matchup.

Non-goals (keep scope tight):

- Real-time solving during play.
- Multiway postflop solution coverage.
- Turn/river trainers in V1.
- Leaderboards.

## Current architecture constraints

- UI is **QML** (`poker/qml/*`) with pages hosted in `Main.qml` `StackLayout`.
- Engine is **C++** `game` (`poker/poker/game.*`) and syncs state to QML via `setProperty` (`game_ui_sync.cpp`).
- Persistence today is via **`QSettings`** (no DB) in `session_store.*` and parts of `game`.

Implication: V1 training content should ship as **static assets** (JSON files in resources) plus lightweight **QSettings** persistence for progress.

## Data model additions

### 1) Training content (static, versioned)

Add `poker/qml/assets/training/` (or `poker/assets/training/`) embedded via `application.qrc`.

- **Preflop ranges** (`preflop_ranges_v1.json`)
  - Keyed by: `format` (cash), `stackDepthBb` (100), `position` (UTG/CO/BTN/SB/BB), and optionally `vsAction` (open, vs3bet, 3bet).
  - For each scenario: action frequencies for each hand cell (13×13).
  - Example schema:
    - `ranges[position].open[hand] = { fold: 0.0, call: 0.2, raise: 0.8 }`
    - `ranges[position].vs3bet[hand] = { fold, call, raise }`

- **Postflop spots** (`spots_v1.json`)
  - Start with SRP **BTN vs BB**, **flop only**, fixed sizing set: `check`, `bet33`, `bet75`.
  - Each spot includes:
    - `heroPosition`, `villainPosition`, `board` (3 cards), `heroHand` (or hero range bucket), `pot`, `stack`.
    - `strategy`: action frequencies.
    - `ev`: EV for each action, and best EV.
    - `tags`: explanation snippets like `range_bet`, `check_range`, `bluff_catcher`.

- **GTO bot strategy DB** (`gto_bot_v1.json` or multiple files)
  - Initially narrow: SRP BTN vs BB; expand later.
  - Keyed by: street, board, action history bucket, and hero hand/range bucket.

### 2) Progress tracking (persistent)

Add a new persistence module, e.g. `training_store.*`:

- Store:
  - Accuracy metrics: by position, by street, by spot type.
  - EV lost totals and recent history.
  - Per-spot mistake counts and “leak” scores.
  - Streak / XP counters.
  - Last daily challenge completion timestamp.

Implementation: `QSettings` with a **schema version** key, e.g. `training/v1/*`.

## UI changes (QML)

### New screens

Add pages to `Main.qml` stack:

- `TrainerHome.qml`
  - Entry points: Preflop Trainer, Flop Trainer, Play vs GTO, Range Viewer, Progress Dashboard.

- `PreflopTrainer.qml`
  - Show: position, hole cards, actions (Fold/Call/Raise), and immediate feedback.
  - Drill configuration: position selector (UTG/CO/BTN/SB/BB), mode (open / 3bet / vs3bet).

- `FlopTrainer.qml`
  - Flow: hero hand + flop shown; choose Check / Bet 33 / Bet 75.
  - Result panel: GTO freq, EV(action), EV(best), mistake size, tags.

- `ReviewScreen.qml` (optional V1 if time)
  - After play vs bot: list of decisions with EV loss and “correct” action.

Enhance existing:

- `StatsScreen.qml` → become “Progress dashboard” (or add a second tab).
- `RangeGrid.qml` → used by Range Viewer + Preflop trainer display.

### Shared components

- `ActionFeedbackPanel.qml`: shows correct/mix/wrong + EVs + tags.
- `DrillHeader.qml`: shows scenario label and progress in session.

## Engine / C++ additions

### 1) Training controller QObject

Add `training_controller.*` (QObject) exposed to QML as `trainer`:

- **Responsibilities**
  - Load training JSON assets (ranges/spots/bot DB).
  - Generate next scenario for a selected drill mode.
  - Score the user decision: correct/mix/wrong, EV loss, explanation tags.
  - Record progress into `training_store`.

- **Minimal QML API**
  - `Q_INVOKABLE void startPreflopDrill(QString position, QString mode)`
  - `Q_INVOKABLE QVariantMap nextPreflopQuestion()`
  - `Q_INVOKABLE QVariantMap submitPreflopAnswer(QString action, int raiseSizeBb)`
  - `Q_INVOKABLE void startFlopDrill(QString matchup)` (BTNvsBB)
  - `Q_INVOKABLE QVariantMap nextFlopQuestion()`
  - `Q_INVOKABLE QVariantMap submitFlopAnswer(QString action)`
  - `Q_PROPERTY QVariantMap lastFeedback READ lastFeedback NOTIFY lastFeedbackChanged`

### 2) Hand representation utilities (shared)

Use existing card parsing utilities where possible; add helpers for:

- Canonical hand key for grids: `AKs`, `AQo`, `77`, etc.
- Board key normalization for spot lookup (e.g. `AhKd7c` order-invariant if DB is keyed by ranks/suits).

### 3) EV and “mix” scoring conventions

Define a stable rule so feedback is consistent:

- **Correct**: chosen action frequency ≥ 0.70 (or is the unique best EV action)
- **Mix**: 0.05 ≤ frequency < 0.70
- **Wrong**: frequency < 0.05
- **EV loss**: `EV(best) - EV(chosen)` (0 for best action, positive otherwise)

Expose these in `submit*Answer` responses.

### 4) Play vs GTO bot integration

Phase 1 (MVP):

- Keep `game` as the dealer/betting engine.
- Add an opt-in “GTO bot seat strategy” that delegates decisions to `training_controller` (or a new `gto_bot.*`).
- Record per-decision EV loss for the human seat using the same DB used by trainers (where coverage exists).

Phase 2:

- Expand DB and add state bucketing for action histories.

## Implementation plan (sequenced)

### Milestone A — Preflop trainer (fastest value)

- Add training JSON asset + loader.
- Implement `training_controller` preflop path + `training_store` persistence.
- Add `PreflopTrainer.qml` screen + simple drill config.
- Hook into `StatsScreen` to display accuracy by position.

### Milestone B — Flop spot trainer (BTN vs BB, flop only)

- Add `spots_v1.json` with a small starter set.
- Implement `FlopTrainer.qml` + feedback panel.
- Add EV lost aggregation and “biggest mistake spots”.

### Milestone C — EV feedback + dashboard

- Centralize feedback UI panel used by both trainers.
- Add dashboard cards: biggest leak, recommended drill CTA.

### Milestone D — Play vs GTO bot (narrow coverage)

- Implement GTO bot decision provider (SRP BTN vs BB).
- Add after-hand review list of decisions and EV loss.

## Required repo changes (file list)

### C++

- `poker/main.cpp`: expose new singletons/objects to QML (`trainer`, `trainingStore`).
- `poker/poker/training_controller.{hpp,cpp}` (new)
- `poker/poker/training_store.{hpp,cpp}` (new)
- `poker/poker/gto_bot.{hpp,cpp}` (optional for Milestone D)

### QML

- `poker/qml/TrainerHome.qml` (new)
- `poker/qml/PreflopTrainer.qml` (new)
- `poker/qml/FlopTrainer.qml` (new)
- `poker/qml/ActionFeedbackPanel.qml` (new)
- `poker/qml/RangeViewer.qml` (new, can reuse `RangeGrid.qml`)
- `poker/qml/Main.qml`: add navigation to trainer screens

### Assets

- `poker/qml/assets/training/preflop_ranges_v1.json`
- `poker/qml/assets/training/spots_v1.json`
- `poker/qml/assets/training/gto_bot_v1.json` (later)
- Update `poker/qml/application.qrc` to embed training assets

### Tests

- Add unit tests for:
  - preflop hand-key mapping
  - scoring thresholds (correct/mix/wrong)
  - side-pot and EV loss aggregation in `training_store`

## Notes / open decisions (keep simple)

- Preflop “Call” frequency: some positions may be raise-or-fold in many charts; still allow Call button but grade per DB.
- Raise sizing in preflop trainer: V1 can ignore size and grade only “raise vs not”.
- EV units: use chips or bb consistently; pick one and stick to it in JSON + UI.

## Parallel implementation notes (from focused agents)

### Preflop trainer (reuse `RangeMatrix` / `RangeGrid`)

- Use `RangeMatrix` as the internal 13×13 representation and keep `RangeGrid.qml` **read-only** for reference charts.
- Prefer a minimal JSON schema where each scenario stores **169-length** arrays for `fold/call/raise`.
- Add a dedicated `preflop_trainer` (or broader `training_controller`) QObject exposed to QML (similar to `pokerSolver` / `sessionStore`).

### Flop spot trainer (BTN vs BB, flop only)

- Implement as a second mode of the same `training_controller`:
  - `startFlopDrill("srp_btn_bb")`, `nextFlopQuestion()`, `submitFlopAnswer(action)`.
- Store a tiny `spots_v1.json` with 3–5 textures initially (dry A-high, wet connected, paired low, monotone, dry K-high).

### Progress tracking (QSettings, versioned)

- Add `training_store.*` with keys under `v1/training/*`:
  - scalar totals: `totalDecisions`, `totalCorrect`, `totalEvLossBb`, `streak*`
  - JSON rollup: `rollupJson` containing per-position / per-street / per-spot aggregates.
- Easiest UI: add a **Training** tab or panel in `StatsScreen.qml` bound to `trainingStore.loadProgress()`.

### Play vs GTO bot (staged)

- Add a new `BotStrategy` backed by a pre-solved DB **only** for SRP BTN vs BB initially.
- Treat the bot as **tree-aware** only for discrete action sizes (snap/fallback otherwise).
- Stage rollout:
  - Stage 0: record action history + no behavior change
  - Stage 1: DB loader + lookup + safe fallback to existing bot
  - Stage 2: preflop SRP detection
  - Stage 3: flop-only decisions + human review logging (EV loss where DB covers)


