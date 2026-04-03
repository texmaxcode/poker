# What the app implements (engine + UI)

This describes **no-limit Texas Hold’em** as it actually runs in **Texas Hold’em Gym**—the same style of play-money cash table you get on sites like **Global Poker**: fixed blinds, optional stakes in setup, one human seat vs bots, **no antes**, **no straddles**, and chip conservation through standard **side-pot** math in the engine. The **table shows one total pot**; payouts use a full contribution-tier split (`holdem_nlhe_side_pot_breakdown` in `do_payouts`).

---

## Table and stakes

- **Blinds** — You set **small blind**, **big blind**, and **street bet** (used as a default open/raise unit for bots). Values are persisted with `QSettings`.
- **Buy-in** — Each seat has a target **buy-in** (chips on the table). Amount is capped at **100× the current big blind** (`maxBuyInChips()`). Anything above that stays **off the table** as wallet chips until applied or used for rebuy.
- **Rebuy** — If a seat’s stack hits **0** and the wallet still covers one full buy-in, the player can **buy back in** when the table is idle (human uses the HUD button; bots auto-rebuy from a synthetic reserve when configured).

---

## Hand lifecycle (`game::start`, `beginNewHand`)

1. **New hand** — `beginNewHand()` calls `start()`, which calls `clear_for_new_hand()` to reset street state, pot, contributions, deck; previous hand result text and banner card assets are re-pushed from `last_hand_result_*` so the UI keeps the last winner line until the next showdown updates them.
2. **Blinds** — `collect_blinds` / `compute_blind_seats`:
   - **Three or more active players** — SB is the first active seat clockwise from the button; BB is the next active seat clockwise from the SB.
   - **Heads-up** — Button posts the **small blind**; the other seat posts the **big blind** (standard online convention).
3. **Hole cards** — Two cards per active seat (`deal_hold_cards`).
4. **Streets** — Preflop → flop (three cards) → turn → river. A **burn** card is discarded from the deck before dealing **flop**, **turn**, and **river**.
5. **Betting** — `run_street_betting` for each street; action order comes from `action_order()`:
   - **Preflop** — First to act is `first_in_hand_after(bb_seat_)` (UTG: clockwise after the big blind; heads-up: the button / small blind).
   - **Flop / turn / river** — First to act is `first_in_hand_after(button)` among seats still **in the hand** (so the small blind leads when still in; in heads-up postflop, the big blind acts first).
6. **Fold wins** — If only one player remains, they take the pot without a showdown (`award_pot_to_last_standing`).
7. **Showdown** — `do_payouts` compares hole cards + board (`hand_eval`), awards **main and side pots** by walking **sorted unique per-seat hand contributions**; chops split evenly with remainder chips assigned in code order.

---

## Betting and actions

- **Fold, check, call, bet, raise, all-in** — Implemented per street; stacks are clamped on pay/take.
- **Illegal check facing a bet** — Not offered: `humanCanCheck` and engine state only allow check when there is nothing to call.
- **Minimum raise** — `min_raise_increment_chips` (at least the big blind, or last raise increment as applicable).
- **All-in** — Players with no chips behind skip further action on a check/bet round (`handle_postflop_check_or_bet` / forced-response paths skip `stack <= 0`).
- **Side pots** — Built from each seat’s **total chips put into the current hand** (`hand_contrib_`). The engine allocates every chip; the **center HUD only displays the total pot**, not a main/side breakdown.

---

## Hand evaluation

- **Best five of seven** — Any combination of hole + board; `hand_eval` / `compare_holdem_hands`.
- **Standard high rankings** — High card through royal flush; ties use kickers as implemented in `compare_holdem_hands`.
- **Showdown messaging** — Result strings can reference **last aggressor on the river** when there was a bet or raise there; if the river **checked through**, copy uses **clockwise from the button** for “first show” wording (logical messaging; physical card reveal order in the UI may still be simplified).

---

## Bots and human

- **Human** — Seat 0; timed decisions; fold / call / raise / check / bet as appropriate; can sit out.
- **Bots** — Seats 1–5; configurable strategy and range weights; optional participation toggles; optional slower action pacing for readability.

---

## Bankroll and stats

- After each completed hand, **bankroll snapshots** (stack + wallet per seat) can update **Bankroll & stats** charts and leaderboards; `sessionStatsChanged` / `statsSeq` keep QML in sync with `seatRankings()` and related APIs.

---

## Not implemented (by design)

- **Antes**, **straddles**, **missed-blind** procedures, **dead button** fixes, **tournament** structures, **add-ons**, or **time banks** beyond the simple decision timer.
- **Procedural card-room** conventions (missed blinds, dead buttons, tournament structures) beyond what the engine needs for a single cash table session.

---

## Code map

| Area | Primary files |
|------|----------------|
| Cards, deck, burns | `cards.hpp` / `cards.cpp` |
| Player stack, hole cards | `player.hpp` / `player.cpp` |
| Best hand, compare, descriptions | `hand_eval.hpp` / `hand_eval.cpp` |
| Side-pot chip math | `holdem_side_pot.hpp` / `holdem_side_pot.cpp` — used in **`do_payouts`** |
| Full table engine | `game.hpp` / `game.cpp`, `game_ui_sync.cpp` |
| QML table / HUD | `GameScreen.qml`, `GameControls.qml`, `Table.qml`, … |

---

## Tests

- `poker/poker/tests/test.cpp` — Boost.Test smoke tests (cards, hand comparison, side-pot breakdown helper, samples for equity/range code paths). Build with `BUILD_TESTING=ON`, run `Test_poker` or `ctest`.
