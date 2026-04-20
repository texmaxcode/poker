# SQLite → Parquet for Python analysis

This guide explains how to **read the app’s SQLite database** from **Python** and **write Parquet** files for fast, columnar exploration (pandas, Polars, DuckDB, PyArrow).

## Where the database lives

| Situation | Path |
|-----------|------|
| **Default (Linux)** | `~/.local/share/TexasHoldemGym/Texas Hold'em Gym/texas-holdem-gym.sqlite` |
| **Override** | Set environment variable **`TEXAS_HOLDEM_GYM_SQLITE`** to an **absolute** path before starting the app (or tests). |

The file is often accompanied by **`…-shm`** and **`…-wal`** sidecar files (**[WAL](https://www.sqlite.org/wal.html)** mode). Treat the **directory** as the unit of copy if you snapshot the DB.

## Before you read: close the app or copy the file

With WAL enabled, another process can read the database while the app runs, but **writers** hold locks. For reproducible exports:

1. **Quit Texas Hold’em Gym**, or  
2. **Copy** the `.sqlite` file (and optionally `.sqlite-wal` + `.sqlite-shm`) to a **read-only** path and point your script at the copy.

If SQLite falls back to **QSettings** (INI) because the DB could not be opened, there is **no** `hands` / `actions` / `players` relational data—only the legacy key layout under config. This document assumes **SQLite is in use**.

## What is in the database

### Key–value settings (`kv`)

| Table | Purpose |
|-------|---------|
| **`kv`** | Rows `(k, v)` where **`k`** is a dotted key (e.g. `v1/smallBlind`, `v1/seat0/strategy`) and **`v`** is **JSON text** (objects, arrays, or encoded scalars). The app reuses prepared **`SELECT` / `INSERT`** statements for these rows at runtime (still plain SQL for ad-hoc tools below). |

Useful for reproducing stakes, strategies, and training blobs—not for per-action hand logs.

### Hand log (normalized, `user_version = 1`)

Created by `AppStateSqlite` when the hand-log schema is migrated. Written during play via **`HandLogBatch`** / `game` recording.

#### `players`

| Column | Meaning |
|--------|---------|
| `id` | Surrogate primary key |
| `created_ms` | Epoch ms when first seen |
| `player_key` | Stable logical id (app uses `session_key * 64 + seat`) |

#### `hands`

| Column | Meaning |
|--------|---------|
| `id` | Hand id |
| `started_ms`, `ended_ms` | Wall-clock epoch ms |
| `session_key` | Session bucket for `player_key` |
| `button_seat`, `sb_seat`, `bb_seat` | Seat indices |
| `num_players` | Dealt-in count for that hand |
| `sb_size`, `bb_size` | Posted blind sizes (chips) |
| `board_c0` … `board_c4` | Board cards as **integers** `0..51` or **`-1`** if not yet dealt / unused slot (see decoding below) |
| `result_flags` | Bit mask of seats that **gained** chips vs start-of-hand snapshot (implementation detail; use for winner hints) |

#### `actions`

| Column | Meaning |
|--------|---------|
| `id` | Row id |
| `hand_id` | FK → `hands.id` |
| `seq` | Order within the hand |
| `player_id` | FK → `players.id` |
| `street` | `0` preflop, `1` flop, `2` turn, `3` river, `4` showdown (see `HandLogStreet` in `hand_log_store.hpp`) |
| `action_kind` | `0` fold, `1` check, `2` call, `3` bet, `4` raise, `5` all-in (`HandLogAction` in `hand_log_store.hpp`) |
| `size_chips` | Chip amount where applicable |
| `facing_size` | Facing bet / level context at action time |
| `extra` | Flags; bit **0** set ⇒ blind post (SB/BB) |

#### Decoding `board_c*` (0–51)

Encoding matches **`encode_card_int`** in `game.cpp` and **`decode_card_display`** in `hand_history_query.cpp`:

- **`rank_index = code // 4`** with **0 = TWO … 12 = ACE** (same as `Rank` enum offset from two).
- **`suit_index = code % 4`** with **0 = clubs, 1 = spades, 2 = hearts, 3 = diamonds** (i.e. `Suite` in C++ minus one: clubs=1 … diamonds=4).

Example for notebooks:

```python
RANKS = "23456789TJQKA"
SUITS = "♣♠♥♦"  # clubs, spades, hearts, diamonds — matches suit_index 0..3

def card_code_to_str(c: int):
    if c is None or c < 0 or c > 51:
        return None
    r, s = divmod(c, 4)
    return f"{RANKS[r]}{SUITS[s]}"
```

## Python environment

Minimal:

```bash
python -m venv .venv-analysis
source .venv-analysis/bin/activate  # Windows: .venv-analysis\Scripts\activate
pip install pandas pyarrow
```

Optional (nice for SQL-heavy workflows):

```bash
pip install duckdb sqlalchemy
```

## Option A — pandas + SQLAlchemy → Parquet

```python
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine

DB = Path.home() / ".local/share/TexasHoldemGym/Texas Hold'em Gym/texas-holdem-gym.sqlite"
engine = create_engine(f"sqlite:///{DB.as_posix()}")

hands = pd.read_sql("SELECT * FROM hands ORDER BY started_ms", engine)
actions = pd.read_sql("SELECT * FROM actions ORDER BY hand_id, seq", engine)
players = pd.read_sql("SELECT * FROM players", engine)

out = Path("~/poker_export".expanduser())
out.mkdir(parents=True, exist_ok=True)
hands.to_parquet(out / "hands.parquet", index=False)
actions.to_parquet(out / "actions.parquet", index=False)
players.to_parquet(out / "players.parquet", index=False)
```

Joined denormalized frame (one row per action with hand metadata):

```python
sql = """
SELECT a.*, h.started_ms, h.ended_ms, h.sb_size, h.bb_size, h.button_seat,
       h.board_c0, h.board_c1, h.board_c2, h.board_c3, h.board_c4,
       p.player_key
FROM actions a
JOIN hands h ON h.id = a.hand_id
JOIN players p ON p.id = a.player_id
ORDER BY h.started_ms, a.seq
"""
actions_wide = pd.read_sql(sql, engine)
actions_wide.to_parquet(out / "actions_with_hands.parquet", index=False)
```

## Option B — DuckDB (SQL in, Parquet out)

[DuckDB](https://duckdb.org/) (recent **0.9+**) can attach a SQLite file and **`COPY … TO`** Parquet:

```sql
INSTALL sqlite;
LOAD sqlite;

ATTACH 'path/to/texas-holdem-gym.sqlite' AS poker (TYPE sqlite);

COPY (SELECT * FROM poker.hands) TO 'hands.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM poker.actions) TO 'actions.parquet' (FORMAT PARQUET);
COPY (SELECT * FROM poker.players) TO 'players.parquet' (FORMAT PARQUET);
```

From the shell, pass the **real** path to your `.sqlite` file (mind quotes if the path contains spaces):

```bash
duckdb -c "ATTACH '/home/you/.local/share/TexasHoldemGym/Texas Hold''em Gym/texas-holdem-gym.sqlite' AS poker (TYPE sqlite); COPY (SELECT * FROM poker.hands) TO 'hands.parquet' (FORMAT PARQUET);"
```

## Option C — Polars

If you use **[Polars](https://pola.rs/)** with **`connectorx`** (or another DB URI backend), you can stream straight to Parquet:

```python
from pathlib import Path
import polars as pl

db = Path.home() / ".local/share/TexasHoldemGym/Texas Hold'em Gym/texas-holdem-gym.sqlite"
uri = f"sqlite:///{db.as_posix()}"
hands = pl.read_database_uri("SELECT * FROM hands", uri)
hands.write_parquet("hands.parquet")
```

If `read_database_uri` is unavailable or SQLite URI handling fails for your version, use **pandas** `read_sql` and **`pl.from_pandas`**, or export with **DuckDB** above then `pl.read_parquet`.

## Reading Parquet back

```python
import pandas as pd

hands = pd.read_parquet("hands.parquet")
```

Or in DuckDB:

```sql
SELECT count(*) FROM read_parquet('hands.parquet');
```

## Settings (`kv`) as Parquet

Everything in **`kv`** is JSON text—wide keys, ragged shapes. A simple export:

```python
import json
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(f"sqlite:///{DB.as_posix()}")
kv = pd.read_sql("SELECT k AS key, v AS json_text FROM kv", engine)

def try_parse(s):
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        return None

kv["value"] = kv["json_text"].map(try_parse)
kv.to_parquet("kv.parquet", index=False)
```

For heavy JSON analytics, consider **DuckDB**’s `read_json_auto` after exporting **`v`** to newline-delimited JSON, or keep analysis in SQLite.

## Related code (for maintainers)

| Area | Files |
|------|--------|
| Schema + PRAGMAs | `poker/poker/persist_sqlite.cpp` (`ensureHandLogSchemaV1`, `applyEmbeddedDbTuningPragmas`) |
| Batched writes | `poker/poker/hand_log_store.{hpp,cpp}` |
| Read API for QML | `poker/poker/hand_history_query.{hpp,cpp}` |
| Recording hook | `poker/poker/game.cpp` (`hand_log_*`, `complete_hand_idle`) |

---

*If you add new columns or tables, bump the documented `PRAGMA user_version` strategy in code and update this file in the same change.*
