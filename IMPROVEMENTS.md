# Improvements backlog

Actionable tasks grouped by area. Each item is self-contained and can be executed independently.

---

## QML — component extraction

- [ ] **Extract `HudButton` component** — `GameControls.qml` has ~10 identical `Rectangle + Text + MouseArea` blocks for action buttons (FOLD, CALL, RAISE, CHECK, etc.). Create a reusable `HudButton.qml` with props: `label`, `buttonColor`, `textColor`, `onClicked`. Replace all occurrences in `GameControls.qml`. Register it in `application.qrc`.

- [ ] **Extract `PresetChip` component** — `SizingPresetBar.qml` repeats the same `Rectangle + Text + MouseArea` for each preset (Min, ⅓, ½, ⅔, Pot, All). Replace with a `Repeater` + `ListModel` or an inline `component PresetChip`, parameterized by `label`, `width`, and `onClicked` callback.

- [ ] **Consolidate embedded vs full-width timer rows** — `GameControls.qml` has two nearly identical "Act" + timer + "More" layouts: `statusRow` (non-embedded) and `embeddedChromeCol` (embedded). Extract a shared component or use a single layout whose sizing adapts to `embeddedMode`.

## QML — cleanup

- [ ] **Remove `humanHudVisible` constant** — `Game.qml` line ~99: `readonly property bool humanHudVisible: true`. This is always `true` and only gates `GameControls.visible`. Either remove it and set `visible: true` directly, or make it actually dynamic if sit-out should hide the HUD entirely.

- [ ] **Remove unused `Game.qml` properties** — `smallBlind`, `bigBlind`, `streetPhase`, `seatWallets` are set by C++ but never read in QML. They can be safely removed from `Game.qml`; the engine writes them via `setProperty` but nothing binds to them. If a future feature needs them, they can be re-added.

- [ ] **Remove `interactivePeek` from `Card.qml`** — The `interactivePeek` property and its `MouseArea` (click-to-flip) are never set `true` by any parent. Remove the property and the `MouseArea` block unless you plan to add a "peek at your cards" feature.

- [ ] **Remove zero-margin anchors** — `Game.qml` `tableArea` sets `anchors.*Margin: 0` which is the default. Remove these four lines.

- [ ] **Add `cursorShape: Qt.PointingHandCursor`** to all standard controls (`Button`, `CheckBox`, `Switch`, `TabButton`) in `SetupScreen.qml`, `SolverScreen.qml`, `StatsScreen.qml`. Can be done by wrapping each in a transparent `MouseArea` with `acceptedButtons: Qt.NoButton` and `cursorShape: Qt.PointingHandCursor`, or by setting a global application style.

- [ ] **Add hover highlight to `RangeGrid.qml` cells** — When not `readOnly`, cells should show a subtle background tint on hover (e.g. `Qt.alpha("white", 0.08)`). Currently they only change on click.

## C++ — cleanup

- [ ] **Consolidate `layer_matrix` / `layer_matrix_c`** — `game.cpp` lines ~56–79: two functions with identical `switch (layer)` logic, differing only by `const`. Replace with a single template or use `const_cast` internally to reduce duplication.

- [ ] **Consolidate `bot_preflop_continue_p` / `bot_postflop_continue_p`** — `bot.cpp`: both share the same "clamp → pow → uniform trial" pattern. Extract a shared helper `bot_continue_trial(double exponent, double metric, std::mt19937&)` and call it from both.

- [ ] **Keep `BotNames.qml` and `seat_display_name()` in sync** — `game.cpp` line ~82 duplicates the bot display name array from `BotNames.qml`. Either generate one from the other, or add a test that verifies they match.

- [ ] **Cache `get_hand_vector` in `do_payouts()`** — `game.cpp` `do_payouts()` calls `get_hand_vector(seat)` multiple times per contender (building a fresh `std::vector<card>` each time). Pre-compute and store the seven-card vectors for all contenders before the comparison loop.

- [ ] **Cache `card_to_qml_asset_path` results** — `cards.cpp`: this allocates multiple `QString`s per card on every `sync_ui()`. Since there are only 52 cards, a static lookup table (built once) would eliminate per-frame allocations.

## C++ — dead code

- [ ] **Remove `HandRank` enum** — `cards.hpp` defined `enum class HandRank` which is unused everywhere. (Done in this pass, but verify no external consumers.)

- [ ] **Remove `same_suite` inline** — `cards.hpp`: `same_suite()` has no callers. (Done in this pass.)

- [ ] **Remove `player(card, card)` constructor** — `player.hpp` line 14: never called from production code (only `take_hold_cards` or direct assignment is used). `take_hold_cards` is also test-only but useful to keep.

## Performance

- [ ] **Move bot decisions off the main thread** — Currently bots run on the main thread with `processEvents` loops for pacing. A cleaner approach: run the hand loop in a `QThread`, post UI updates via signals, and use `QTimer::singleShot` for pacing instead of busy-waiting. This is a larger refactor but would make the UI fully fluid during bot actions.

- [ ] **Reduce `sync_ui()` frequency** — `sync_ui()` rebuilds six `QVariantList` arrays and sets ~30 properties on every call. Consider dirty-flagging changed properties and only updating them when they've actually changed, or batching multiple seat changes into a single update.

- [ ] **Use `QML_ELEMENT` registration** — Instead of `setProperty` on the root object (which bypasses QML's binding system), register `game` as a QML type and expose properties as `Q_PROPERTY` with `NOTIFY` signals. This enables efficient binding-level updates instead of polling.

## UI / UX

- [ ] **Add card deal sound effects** — Play a short audio clip when cards are dealt, chips are placed, or the pot is awarded. Use `QtMultimedia` `SoundEffect` for low-latency playback.

- [ ] **Animate chip movement** — When a seat bets, show a chip graphic moving from the seat to the pot. Currently the pot number just increments.

- [ ] **Add hand history log** — Show a scrollable log of actions taken in the current hand (who bet, raised, folded, etc.) in a small panel or popup.

- [ ] **Win/loss splash** — After showdown, show a brief overlay with the winning hand description and which seat(s) won, before transitioning to the next hand.

- [ ] **Mobile / touch layout** — The current layout targets desktop. For touch, buttons need to be larger (min 44×44px touch targets) and the HUD should be repositioned to avoid occlusion by on-screen keyboards.

- [ ] **Dark/light theme toggle** — `Theme.qml` currently only has a dark palette. Add a light variant and a toggle in the lobby or header.
