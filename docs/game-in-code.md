# What the app implements (engine + UI)

This describes **no-limit Texas Hold’em** as it actually runs in **Texas Hold’em Gym**—the same style of play-money cash table you get on sites like **Global Poker**: fixed blinds, optional stakes in setup, one human seat vs bots, **no antes**, **no straddles**, and chip conservation through standard **main + side pot** math in the engine. The **table HUD shows one total pot** (like Global Poker’s felt); at **showdown**, the result banner can list **Main pot** and **Side pot 1, 2, …** when more than one pot exists (`do_payouts`).

---

## Table and stakes

- **Blinds** — You set **small blind**, **big blind**, and **street bet** (used as a default open/raise unit for bots). Values are persisted with `QSettings`.
- **Buy-in** — Each seat has a target **buy-in** (chips on the table). Amount is capped at **100× the current big blind** (`maxBuyInChips()`). Anything above that stays **off the table** as wallet chips until applied or used for rebuy.
- **Rebuy** — If a seat’s stack hits **0** and the wallet still covers one full buy-in, the player can **buy back in** when the table is idle (human uses the HUD button; bots auto-rebuy from a synthetic reserve when configured).

---

## Hand lifecycle (`game::start`, `beginNewHand`)

1. **New hand** — `beginNewHand()` calls `start()`, which calls `clear_for_new_hand()` to reset street state, pot, contributions, deck; previous hand result text and banner card assets are re-pushed from `last_hand_result_*` so the UI keeps the last winner line until the next showdown updates them.
2. **Blinds** — `collect_blinds` / `compute_blind_seats`:
   - **Three or more active players** — SB is the first active seat **clockwise** from the button, BB the next clockwise from the SB (same order as live / online NLHE).
   - **Heads-up** — Button posts the **small blind**; the other seat posts the **big blind**.
3. **Hole cards** — Two cards per active seat (`deal_hold_cards`).
4. **Streets** — Preflop → flop (three cards) → turn → river. A **burn** card is discarded from the deck before dealing **flop**, **turn**, and **river**.
5. **Betting** — `run_street_betting` for each street; action order comes from `action_order()` (same **clockwise** direction as the dealer button advance).
   - **Seat numbering** — `GameScreen` places seat **0** (human) on the felt and increases the index around the oval; geometrically that walks **counter-clockwise** on the layout, so **clockwise** poker order in code is **next lower index** with wrap: `(seat + n - 1) % n` (`first_in_hand_after`, `next_seat_in_position_pool`, deal order).
   - **Preflop** — First to act is `first_in_hand_after(bb_seat_)` (UTG after the big blind; heads-up: the button / small blind).
   - **Flop / turn / river** — First to act is `first_in_hand_after(button)` among seats still **in the hand** (small blind leads when still in; heads-up postflop, big blind acts first).
6. **Fold wins** — If only one player remains, they take the pot without a showdown (`award_pot_to_last_standing`).
7. **Showdown** — `do_payouts` compares hole cards + board (`hand_eval`) and pays **main pot** and **side pots** the same way major sites do: from each seat’s **total contribution this hand** (`hand_contrib_`), build **one main pot** (everyone’s money up to the smallest stack in play for that layer) and **side pots** for each deeper stack; each physical pot is won by the best hand among players **eligible for that pot** (and chops split evenly, remainder by seat order).

---

## Main pot and side pots (Global Poker–style)

This is **not** a separate rules system—it is the usual NLHE **main + side pot** breakdown:

- **Main pot** — Chips everyone matched who was still contesting that “layer” (short stack, then the next, etc.).
- **Side pot 1, side pot 2, …** — Extra chips only the deeper stacks put in; each side pot is awarded only to players who **put in enough** to be in that pot **and** are still live at showdown (with a fallback when the only funders folded—see `do_payouts`).

The engine computes chip amounts with `holdem_nlhe_side_pot_breakdown()` (sorted **unique contribution depths** → one amount per **main or side pot**). The UI does **not** show a running main/side split in the center; only the **total** is on the table during play.

---

## Betting and actions

- **Fold, check, call, bet, raise, all-in** — Implemented per street; stacks are clamped on pay/take.
- **Illegal check facing a bet** — Not offered: `humanCanCheck` and engine state only allow check when there is nothing to call.
- **Minimum raise** — `min_raise_increment_chips` (at least the big blind, or last raise increment as applicable).
- **All-in** — Players with no chips behind skip further action on a check/bet round (`handle_postflop_check_or_bet` / forced-response paths skip `stack <= 0`).
- **Side pots** — Same as above: built from each seat’s **total chips put into the current hand** (`hand_contrib_`). The **center HUD only shows combined pot size** during the hand; **main / side labels** appear in the **showdown banner** when applicable.

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
