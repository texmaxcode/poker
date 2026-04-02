# Rules & limitations

This project implements **no-limit Texas Hold’em** in a way that matches common rules for **action order**, **blinds**, **board dealing**, **showdown order messaging**, and **hand strength** (best five cards from seven). The [Bicycle Cards introduction to Texas Hold’em](https://bicyclecards.com/how-to-play/texas-holdem-poker) is a good plain-language reference for the full game.

Below is what the **engine** guarantees and what it **does not** model.

## What is implemented (summary)

| Topic | Behavior |
|-------|----------|
| **Blinds (3+ players)** | Small blind is the first active seat **clockwise from the button**; big blind is the next active seat clockwise from the SB. |
| **Heads-up blinds** | The **button posts the small blind**; the **other seat posts the big blind** (standard casino / online convention). |
| **Preflop betting order** | Action starts with the first active seat **clockwise from the big blind** (UTG in full ring). |
| **Postflop betting order** | Action starts with the first active seat **clockwise from the button**. |
| **Board** | Hole cards, then flop (three), turn, river; **burn** cards are discarded before each street’s board deal. |
| **Hand evaluation** | Any combination of hole + board; **best five** of seven; standard ranking; chops split the pot evenly (with remainder chips as implemented). |
| **Showdown (message)** | If there was a **bet or raise on the river**, the UI text references **last aggressor**; if the river **checked through**, first show is described as **clockwise from the button**. (Physical card reveal order in UI may still be simplified.) |

## Intentional simplifications

### Side pots

When at least one player is **all-in** for less than others, the **main pot** is the amount everyone matches up to that **shortest all-in**; **side pots** are the extra chips only the deeper stacks contest. The table HUD uses that breakdown. **Payouts** still walk every distinct contribution tier (including dead money from folded seats) so all chips are awarded correctly.

### Antes

**Antes** are not implemented (optional in many structures).

### Busted stacks

Players with **zero chips** are not dealt in as active participants for the next hand (aligned with “cannot play without money” in the app). Rebuy/add-on is not modeled.

### Other table rules

Straddles, missed blinds, dead buttons, and other card-room procedural rules are **out of scope** unless added explicitly later.

## UI vs engine

Seat labels (**BTN**, **SB**, **BB**, **UTG**, etc.) are derived from engine **button** and **SB/BB** seats exposed to QML, not from a fixed 6-max ring formula alone. The table HUD shows **blind amounts**; it does not label which seat is SB/BB beyond the **Player** position tags.
