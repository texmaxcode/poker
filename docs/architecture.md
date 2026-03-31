# Architecture overview

## High-level flow

- `poker/main.cpp` boots a `QGuiApplication`, loads the QML UI from the embedded resource `qrc:/Game.qml`, and wires a `game` instance to the QML root object via `game::setRootObject()`.
- The QML UI emits `buttonClicked(QString)`; `game` listens and starts a new hand (`game::start()`), updating the `pot` property on the QML root via `pot_changed`.

## Core modules

- `poker/poker/cards.*`
  - `card`: rank + suit
  - `card_deck`: generates a standard 52-card deck and shuffles it
- `poker/poker/player.*`
  - `player`: two hole cards and a chip stack
- `poker/poker/game.*`
  - coordinates dealing / betting rounds and exposes basic state for the UI

## Tests

`poker/poker/tests/test.cpp` is a Boost.Test-based smoke suite covering card construction/comparison and a basic game flow.

