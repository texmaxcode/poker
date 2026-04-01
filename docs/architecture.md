# Architecture overview

## High-level picture

Texas Hold’em Gym is a **single-process** desktop app: a **Qt Quick** UI drives a **C++** game engine (`game`), optional **bot** and **range** configuration, **hand evaluation** and **equity** utilities, and a **preflop solver** façade exposed to QML as **`pokerSolver`**.

```
┌─────────────────────────────────────────────────────────┐
│  QML (Main.qml, Game.qml, SetupScreen, Table, …)        │
│       │ signals / setProperty                             │
│       ▼                                                   │
│  game (QObject) · PokerSolver (QObject)                   │
│       │                                                   │
│       ├── cards, player, hand_eval, bot, range_matrix     │
│       ├── equity_engine, poker_solver (may use threads)   │
│       └── no persistent DB; in-memory state only          │
└─────────────────────────────────────────────────────────┘
```

## Application shell

- **`poker/main.cpp`** creates `QGuiApplication`, instantiates **`game`** and **`PokerSolver`**, and exposes them to QML as **`pokerGame`** and **`pokerSolver`** on the root context.
- The UI entry is **`qrc:/Main.qml`**: an `ApplicationWindow` with a **stack** of pages (lobby → table → bot/range setup → solver/equity). Fonts and the header/toolbar live on the window.
- After **`QQmlApplicationEngine::load()`**, a short **`QTimer::singleShot`** finds the table **`Page`** by **`objectName: "game_screen"`**, calls **`game::setRootObject()`** on it, then **`beginNewHand()`** so the first hand starts only when the table is ready. The engine does **not** use `Game.qml` as the root object.

## Game ↔ QML

- **`game`** holds `QObject* m_root` to the table **`Page`**. It connects to **`buttonClicked(QString)`** for HUD actions (fold, call, check, raise, “more time”) from **`GameControls`**.
- Betting runs in C++; when the human must act, the code can spin a **local event loop** (with timers) until QML submits an action via **`submitFacingAction`**, **`submitCheckOrBet`**, etc.
- State is pushed to QML with **`QObject::setProperty`** on the root: pot, board card asset names, per-seat stacks/cards/in-hand flags, button/SB/BB seats, acting seat, timers, street label, and related fields. **`sync_ui()`** centralizes this; **`pot_changed`** / **`ui_state_changed`** notify listeners.
- The live path for a new hand is **`beginNewHand()`** → **`start()`** (full hand through streets and **`do_payouts()`** when appropriate). **`game::start()`** remains usable from tests or automation.

## Core C++ modules (`poker/poker/`)

| Module | Responsibility |
|--------|----------------|
| **`cards.*`** | Ranks, suits, deck, card ordering helpers |
| **`player.*`** | Hole cards, stack, **`pay`** / **`take_from_stack`** (clamped) |
| **`hand_eval.*`** | Best 5 of 7, comparison, human-readable descriptions |
| **`game.*`** | Table vector, button, blinds, streets, **`in_hand`**, betting loop, bots, QML API, **`compute_blind_seats`** (including heads-up rule) |
| **`bot.*`** | Bot strategy enums and decision hooks used from **`game`** |
| **`range_matrix.*`** | Parsing and weights for opening ranges |
| **`equity_engine.*`** | Monte Carlo equity helpers for the solver UI |
| **`poker_solver.*`** | QObject façade for solver work; may delegate to worker/thread pool |

## QML structure (selected)

| File / area | Role |
|-------------|------|
| **`Main.qml`** | Shell: navigation, **`pokerGame`** / **`pokerSolver`** bindings |
| **`Game.qml`** | Table layout, **`game_screen`**, **`Player`** delegates, **`GameControls`** |
| **`GameControls.qml`** | Fold / call / raise / check / bet, timers, sit-out |
| **`Table.qml`** | Pot + blinds HUD, board, street label |
| **`SetupScreen.qml`**, solver screens | Ranges, strategies, solver/equity UI |

Assets (cards, logo) are embedded via **`application.qrc`**.

## Rules and engine fidelity

Betting order, blinds (including **heads-up**), burns before board cards, showdown messaging, and **best hand** selection follow the intended Hold’em model; some **simplifications** apply (e.g. no side pots). See **[rules-and-limitations.md](rules-and-limitations.md)**.

## Tests

- **`poker/poker/tests/test.cpp`** — **Boost.Test** smoke tests: cards, deck, players, hand evaluation, equity spot checks, **`game`** flows (`collect_blinds`, `deal_*`, `decide_the_payout`, etc.).
- **`poker/poker/tests/CMakeLists.txt`** registers **`poker.smoke`** via **`add_test`**.

The **`poker`** library links **Qt::Qml** so MOC’d types used from tests stay consistent with the app’s Qt linkage.
