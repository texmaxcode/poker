#ifndef TEXAS_HOLDEM_GYM_PERSIST_SQLITE_HPP
#define TEXAS_HOLDEM_GYM_PERSIST_SQLITE_HPP

#include <QByteArray>
#include <QString>
#include <QVariant>

struct sqlite3;

/// Key–value store: SQLite at `TEXAS_HOLDEM_GYM_SQLITE` or `AppLocalDataLocation/texas-holdem-gym.sqlite`;
/// if SQLite cannot open, `QSettings` INI under `~/.config/TexasHoldemGym/`. Values are JSON-encoded.
class AppStateSqlite
{
public:
    /// Open database, create schema, migrate from `QSettings` if the DB is empty.
    static void init();
    static bool isOpen();

    static void setValue(const QString &key, const QVariant &value);
    static QVariant value(const QString &key, const QVariant &defaultValue = {});
    static bool contains(const QString &key);

    /// Deletes all keys with the given prefix (e.g. `v1/training/`).
    static void removeKeysWithPrefix(const QString &prefix);

    /// Clears normalized hand-log tables (`actions`, `hands`, `players`). No-op when not using SQLite.
    static void clearHandLogTables();

    static void sync();

    /// Wrap many `setValue` calls in one atomic batch (SQLite only; no-op on INI fallback).
    static void beginTransaction();
    static void commitTransaction();

    /// SQLite path in use, or the INI path when using the QSettings fallback (after `init()`).
    static QString databasePath();

    static QByteArray testVariantToJson(const QVariant &v);
    static bool testJsonToVariant(const QByteArray &json, QVariant *out);

    /// Open `sqlite3` handle when the store uses SQLite; `nullptr` on INI fallback or before `init()`.
    static sqlite3 *sqliteHandle();

    /// Unit tests only: closes SQLite and clears state so `init()` can run again (e.g. after changing env path).
    static void resetForTesting();

private:
    static void migrateFromQSettingsIfEmpty();
};

#endif
