#include "persist_sqlite.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonParseError>
#include <QMetaType>
#include <QSettings>
#include <QStandardPaths>
#include <QtGlobal>

#include <cmath>
#include <sqlite3.h>

#ifndef NDEBUG
#include <climits>
#include <limits>
#endif

namespace {

enum class Backend
{
    None,
    Sqlite,
    QSettingsFallback,
};

QString g_dbPath;
sqlite3 *g_db = nullptr;
Backend g_backend = Backend::None;

bool jsonToVariant(const QByteArray &json, QVariant *out)
{
    const QByteArray trimmed = json.trimmed();
    if (trimmed.isEmpty())
        return false;

    QJsonParseError err{};
    QJsonDocument doc = QJsonDocument::fromJson(trimmed, &err);
    /// Qt only accepts a JSON **object** or **array** at the document root. Values written by
    /// `QJsonDocument::fromVariant` for scalars are compact primitives (`5`, `true`, `"text"`, …),
    /// which `fromJson` rejects — reads would fail and every save would re-write defaults over disk.
    if (err.error == QJsonParseError::NoError && !doc.isNull())
    {
        *out = doc.toVariant();
        return true;
    }

    /// Do not wrap objects/arrays — only bare scalars (`5`, `true`, `"…"`) need the array shim.
    if (trimmed.startsWith('{') || trimmed.startsWith('['))
        return false;

    QJsonParseError err2{};
    const QByteArray wrapped = QByteArrayLiteral("[") + trimmed + QByteArrayLiteral("]");
    doc = QJsonDocument::fromJson(wrapped, &err2);
    if (err2.error != QJsonParseError::NoError || doc.isNull() || !doc.isArray() || doc.array().isEmpty())
        return false;
    *out = doc.array().first().toVariant();
    return true;
}

QByteArray variantToJson(const QVariant &v)
{
    if (!v.isValid())
        return QByteArrayLiteral("null");
    const int tid = v.typeId();
    if (tid == QMetaType::Double || tid == QMetaType::Float)
    {
        const double d = v.toDouble();
        if (!std::isfinite(d))
            return QByteArrayLiteral("0");
    }
    /// `QString` must never use the integer fallback below: `canConvert<qint64>()` is true for strings
    /// (e.g. empty → 0, "0" → 0) and would store range text as JSON number `0`, destroying real strings on save.
    if (tid == QMetaType::QString)
    {
        /// `fromVariant(QString)` yields an empty document; encode as one array element, then drop `[`/`]`.
        const QString s = v.toString();
        QJsonArray arr;
        arr.append(s);
        const QByteArray full = QJsonDocument(arr).toJson(QJsonDocument::Compact);
        if (full.size() >= 2 && full.front() == '[' && full.back() == ']')
            return full.mid(1, full.size() - 2);
        return QByteArrayLiteral("\"\"");
    }
    QJsonDocument doc = QJsonDocument::fromVariant(v);
    QByteArray b = doc.toJson(QJsonDocument::Compact);
    if (b.isNull() || b == QByteArrayLiteral("null"))
    {
        switch (tid)
        {
        case QMetaType::Int:
        case QMetaType::UInt:
        case QMetaType::LongLong:
        case QMetaType::ULongLong:
        case QMetaType::Short:
        case QMetaType::UShort:
        case QMetaType::Char:
        case QMetaType::SChar:
        case QMetaType::UChar:
            return QByteArray::number(v.toLongLong());
        case QMetaType::Double:
        case QMetaType::Float:
            return QByteArray::number(v.toDouble(), 'g', 17);
        case QMetaType::Bool:
            return v.toBool() ? QByteArrayLiteral("true") : QByteArrayLiteral("false");
        default:
            break;
        }
    }
    return b;
}

/// Reused across `value` / `contains` / `setValue` to avoid per-call `sqlite3_prepare_v2` on hot paths.
static sqlite3_stmt *g_stmt_kv_select_v = nullptr;
static sqlite3_stmt *g_stmt_kv_exists = nullptr;
static sqlite3_stmt *g_stmt_kv_upsert = nullptr;

static void finalizeKvPreparedStatements()
{
    if (g_stmt_kv_select_v)
    {
        sqlite3_finalize(g_stmt_kv_select_v);
        g_stmt_kv_select_v = nullptr;
    }
    if (g_stmt_kv_exists)
    {
        sqlite3_finalize(g_stmt_kv_exists);
        g_stmt_kv_exists = nullptr;
    }
    if (g_stmt_kv_upsert)
    {
        sqlite3_finalize(g_stmt_kv_upsert);
        g_stmt_kv_upsert = nullptr;
    }
}

static bool prepareKvPreparedStatements(sqlite3 *db)
{
    finalizeKvPreparedStatements();
    if (!db)
        return false;
    if (sqlite3_prepare_v2(db, "SELECT v FROM kv WHERE k = ?", -1, &g_stmt_kv_select_v, nullptr) != SQLITE_OK)
        return false;
    if (sqlite3_prepare_v2(db, "SELECT 1 FROM kv WHERE k = ? LIMIT 1", -1, &g_stmt_kv_exists, nullptr) != SQLITE_OK)
    {
        finalizeKvPreparedStatements();
        return false;
    }
    if (sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO kv (k, v) VALUES (?, ?)", -1, &g_stmt_kv_upsert, nullptr) != SQLITE_OK)
    {
        finalizeKvPreparedStatements();
        return false;
    }
    return true;
}

void closeDb()
{
    finalizeKvPreparedStatements();
    if (g_db)
    {
        sqlite3_close(g_db);
        g_db = nullptr;
    }
}

/// Stable encoding for logical keys as QSettings keys (slashes are awkward in some backends).
QString flatSettingsKey(const QString &logicalKey)
{
    return QString::fromLatin1(logicalKey.toUtf8().toBase64(
        QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QSettings makeFallbackSettings()
{
    return QSettings(QSettings::IniFormat, QSettings::UserScope,
                     QStringLiteral("TexasHoldemGym"), QStringLiteral("Texas Hold'em Gym"));
}

void qsettingsFallbackSetValue(const QString &key, const QVariant &value)
{
    QSettings s = makeFallbackSettings();
    s.beginGroup(QStringLiteral("kv_json"));
    s.setValue(flatSettingsKey(key), QString::fromUtf8(variantToJson(value)));
    s.sync();
}

QVariant qsettingsFallbackValue(const QString &key, const QVariant &defaultValue)
{
    QSettings s = makeFallbackSettings();
    s.beginGroup(QStringLiteral("kv_json"));
    const QString json = s.value(flatSettingsKey(key)).toString();
    if (json.isEmpty())
        return defaultValue;
    QVariant out;
    if (!jsonToVariant(json.toUtf8(), &out))
        return defaultValue;
    if (!out.isValid())
        return defaultValue;
    return out;
}

bool qsettingsFallbackContains(const QString &key)
{
    QSettings s = makeFallbackSettings();
    s.beginGroup(QStringLiteral("kv_json"));
    const QString enc = flatSettingsKey(key);
    if (!s.contains(enc))
        return false;
    const QString json = s.value(enc).toString();
    if (json.isEmpty())
        return false;
    QVariant out;
    if (!jsonToVariant(json.toUtf8(), &out))
        return false;
    return out.isValid();
}

void qsettingsFallbackRemovePrefix(const QString &prefix)
{
    QSettings s = makeFallbackSettings();
    s.beginGroup(QStringLiteral("kv_json"));
    const QStringList keys = s.allKeys();
    for (const QString &enc : keys)
    {
        const QByteArray raw = QByteArray::fromBase64(
            enc.toLatin1(),
            QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
        const QString logical = QString::fromUtf8(raw);
        if (logical.startsWith(prefix))
            s.remove(enc);
    }
    s.sync();
}

/// Copy legacy `v1/*` from native QSettings into flat `kv_json` if the latter is empty.
void migrateLegacyIntoFallbackIfNeeded()
{
    QSettings s = makeFallbackSettings();
    s.beginGroup(QStringLiteral("kv_json"));
    if (!s.allKeys().isEmpty())
        return;

    QSettings legacy;
    legacy.beginGroup(QStringLiteral("v1"));
    const QStringList keys = legacy.allKeys();
    for (const QString &k : keys)
    {
        const QString full = QStringLiteral("v1/") + k;
        qsettingsFallbackSetValue(full, legacy.value(k));
    }
    legacy.endGroup();
}

#ifndef NDEBUG
static bool isNumericMetaType(int tid)
{
    switch (tid)
    {
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
    case QMetaType::Double:
    case QMetaType::Float:
    case QMetaType::Short:
    case QMetaType::UShort:
    case QMetaType::Char:
    case QMetaType::SChar:
    case QMetaType::UChar:
        return true;
    default:
        return false;
    }
}

static bool doublesMatch(double a, double b)
{
    if (std::isnan(a) && std::isnan(b))
        return true;
    if (!std::isfinite(a) || !std::isfinite(b))
        return false;
    return qFuzzyCompare(a + 1.0, b + 1.0);
}

static bool variantDeepEqual(const QVariant &a, const QVariant &b)
{
    if (a == b)
        return true;
    if (a.typeId() == QMetaType::QVariantList && b.typeId() == QMetaType::QVariantList)
    {
        const QList<QVariant> la = a.toList();
        const QList<QVariant> lb = b.toList();
        if (la.size() != lb.size())
            return false;
        for (int i = 0; i < la.size(); ++i)
        {
            if (!variantDeepEqual(la.at(i), lb.at(i)))
                return false;
        }
        return true;
    }
    if (a.typeId() == QMetaType::QVariantMap && b.typeId() == QMetaType::QVariantMap)
    {
        const QVariantMap ma = a.toMap();
        const QVariantMap mb = b.toMap();
        if (ma.size() != mb.size())
            return false;
        for (auto it = ma.constBegin(); it != ma.constEnd(); ++it)
        {
            if (!mb.contains(it.key()))
                return false;
            if (!variantDeepEqual(it.value(), mb.value(it.key())))
                return false;
        }
        return true;
    }
    if (isNumericMetaType(a.typeId()) && isNumericMetaType(b.typeId()))
        return doublesMatch(a.toDouble(), b.toDouble());
    return false;
}

static QVariant expectedAfterJsonRoundTrip(const QVariant &v)
{
    if (v.typeId() == QMetaType::Double || v.typeId() == QMetaType::Float)
    {
        const double d = v.toDouble();
        if (!std::isfinite(d))
            return QVariant(0);
    }
    return v;
}

bool testJsonRoundTrip()
{
    bool ok = true;
    auto check = [&](const char *label, const QVariant &original) {
        const QVariant expected = expectedAfterJsonRoundTrip(original);
        QVariant parsed;
        const QByteArray json = variantToJson(original);
        if (!jsonToVariant(json, &parsed))
        {
            ok = false;
            qWarning() << "testJsonRoundTrip: parse failed for" << label << "json:" << json;
            return;
        }
        if (!variantDeepEqual(expected, parsed))
        {
            ok = false;
            qWarning() << "testJsonRoundTrip: mismatch for" << label << "expected:" << expected << "got:" << parsed
                       << "json:" << json;
        }
    };

    check("int 0", QVariant(0));
    check("int 1", QVariant(1));
    check("int -1", QVariant(-1));
    check("int 100", QVariant(100));
    check("int INT_MAX", QVariant(INT_MAX));

    check("double 0.0", QVariant(0.0));
    check("double 1.5", QVariant(1.5));
    check("double -3.14", QVariant(-3.14));
    check("double NaN", QVariant(std::numeric_limits<double>::quiet_NaN()));
    check("double Inf", QVariant(std::numeric_limits<double>::infinity()));

    check("bool true", QVariant(true));
    check("bool false", QVariant(false));

    check("QString empty", QVariant(QString()));
    check("QString hello", QVariant(QStringLiteral("hello")));
    check("QString AA AKs", QVariant(QStringLiteral("AA AKs")));
    check("QString v1/seat0/rangeText", QVariant(QStringLiteral("v1/seat0/rangeText")));

    check("QVariantList empty", QVariant(QVariantList()));
    {
        QVariantList list123;
        list123 << 1 << 2 << 3;
        check("QVariantList [1,2,3]", QVariant(list123));
    }
    {
        QVariantList row1;
        row1 << 100 << 200;
        QVariantList row2;
        row2 << 300 << 400;
        QVariantList nested;
        nested << QVariant(row1) << QVariant(row2);
        check("QVariantList nested", QVariant(nested));
    }

    check("QVariantMap empty", QVariant(QVariantMap()));
    {
        QVariantMap m;
        m.insert(QStringLiteral("key"), QStringLiteral("value"));
        check("QVariantMap key-value", QVariant(m));
    }

    return ok;
}
#endif

/// Single store: override with `TEXAS_HOLDEM_GYM_SQLITE`, else `AppLocalDataLocation/texas-holdem-gym.sqlite`.
static QString sqlitePath()
{
    const QString env = qEnvironmentVariable("TEXAS_HOLDEM_GYM_SQLITE");
    if (!env.isEmpty())
        return env;
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (dir.isEmpty())
        return {};
    return QDir(dir).filePath(QStringLiteral("texas-holdem-gym.sqlite"));
}

void cleanupNullRows()
{
    if (g_backend != Backend::Sqlite || !g_db)
        return;
    char *errmsg = nullptr;
    const int rc = sqlite3_exec(
        g_db,
        "DELETE FROM kv WHERE v = 'null'",
        nullptr,
        nullptr,
        &errmsg);
    if (rc != SQLITE_OK)
    {
        qWarning() << "AppStateSqlite: cleanupNullRows" << (errmsg ? errmsg : sqlite3_errmsg(g_db));
        sqlite3_free(errmsg);
        return;
    }
    sqlite3_free(errmsg);
    const int n = sqlite3_changes(g_db);
    qInfo().noquote() << QStringLiteral("AppStateSqlite: cleaned %1 null rows").arg(n);
}

/// Unit tests only: close the DB and allow `AppStateSqlite::init()` to run again.
void appStateSqliteResetForTesting()
{
    closeDb();
    g_backend = Backend::None;
    g_dbPath.clear();
}

} // namespace

static void warnPragma(sqlite3 *db, const char *sql, const char *label)
{
    char *errmsg = nullptr;
    const int rc = sqlite3_exec(db, sql, nullptr, nullptr, &errmsg);
    if (rc != SQLITE_OK)
    {
        qWarning().noquote() << QStringLiteral("AppStateSqlite: %1 failed — %2")
                                    .arg(QLatin1String(label),
                                         QLatin1String(errmsg ? errmsg : sqlite3_errmsg(db)));
        sqlite3_free(errmsg);
    }
}

/// Embedded primary-store tuning (WAL + cache) for the single app database file.
static void applyEmbeddedDbTuningPragmas(sqlite3 *db)
{
    if (!db)
        return;
    warnPragma(db, "PRAGMA foreign_keys = ON;", "PRAGMA foreign_keys");
    warnPragma(db, "PRAGMA journal_mode = WAL;", "PRAGMA journal_mode");
    warnPragma(db, "PRAGMA synchronous = NORMAL;", "PRAGMA synchronous");
    warnPragma(db, "PRAGMA temp_store = MEMORY;", "PRAGMA temp_store");
    warnPragma(db, "PRAGMA mmap_size = 30000000000;", "PRAGMA mmap_size");
    warnPragma(db, "PRAGMA cache_size = -200000;", "PRAGMA cache_size");
}

static bool ensureHandLogSchemaV1(sqlite3 *db)
{
    if (!db)
        return false;

    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(db, "PRAGMA user_version", -1, &st, nullptr) != SQLITE_OK)
        return false;
    if (sqlite3_step(st) != SQLITE_ROW)
    {
        sqlite3_finalize(st);
        return false;
    }
    const int ver = sqlite3_column_int(st, 0);
    sqlite3_finalize(st);
    if (ver >= 1)
        return true;

    static const char kSql[] = R"SQL(
CREATE TABLE IF NOT EXISTS players (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  created_ms INTEGER NOT NULL,
  player_key INTEGER NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS hands (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  started_ms INTEGER NOT NULL,
  ended_ms INTEGER NOT NULL DEFAULT 0,
  session_key INTEGER NOT NULL DEFAULT 0,
  button_seat INTEGER NOT NULL,
  sb_seat INTEGER NOT NULL,
  bb_seat INTEGER NOT NULL,
  num_players INTEGER NOT NULL,
  sb_size INTEGER NOT NULL,
  bb_size INTEGER NOT NULL,
  board_c0 INTEGER NOT NULL DEFAULT -1,
  board_c1 INTEGER NOT NULL DEFAULT -1,
  board_c2 INTEGER NOT NULL DEFAULT -1,
  board_c3 INTEGER NOT NULL DEFAULT -1,
  board_c4 INTEGER NOT NULL DEFAULT -1,
  result_flags INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  hand_id INTEGER NOT NULL REFERENCES hands(id) ON DELETE CASCADE,
  seq INTEGER NOT NULL,
  player_id INTEGER NOT NULL REFERENCES players(id),
  street INTEGER NOT NULL,
  action_kind INTEGER NOT NULL,
  size_chips INTEGER NOT NULL DEFAULT 0,
  facing_size INTEGER NOT NULL DEFAULT 0,
  extra INTEGER NOT NULL DEFAULT 0,
  UNIQUE(hand_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_actions_hand_player ON actions(hand_id, player_id);
CREATE INDEX IF NOT EXISTS idx_actions_hand_seq ON actions(hand_id, seq);
CREATE INDEX IF NOT EXISTS idx_hands_started ON hands(started_ms);
)SQL";

    char *errmsg = nullptr;
    if (sqlite3_exec(db, kSql, nullptr, nullptr, &errmsg) != SQLITE_OK)
    {
        qWarning() << "AppStateSqlite: hand log DDL" << (errmsg ? errmsg : sqlite3_errmsg(db));
        sqlite3_free(errmsg);
        return false;
    }
    sqlite3_free(errmsg);

    char *err2 = nullptr;
    if (sqlite3_exec(db, "PRAGMA user_version = 1", nullptr, nullptr, &err2) != SQLITE_OK)
    {
        qWarning() << "AppStateSqlite: PRAGMA user_version" << (err2 ? err2 : sqlite3_errmsg(db));
        sqlite3_free(err2);
        return false;
    }
    sqlite3_free(err2);
    return true;
}

static bool tryOpenSqliteAtPath(const QString &path)
{
    g_dbPath = path;
    QDir().mkpath(QFileInfo(g_dbPath).absolutePath());

    const QByteArray pathUtf8 = g_dbPath.toUtf8();
    int rc = sqlite3_open_v2(
        pathUtf8.constData(),
        &g_db,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
        nullptr);
    if (rc != SQLITE_OK || !g_db)
    {
        const char *msg = g_db ? sqlite3_errmsg(g_db) : sqlite3_errstr(rc);
        qWarning() << "AppStateSqlite: sqlite3_open_v2 failed for" << g_dbPath << "-" << msg;
        if (g_db)
            sqlite3_close(g_db);
        g_db = nullptr;
        return false;
    }

    sqlite3_busy_timeout(g_db, 8000);

    char *errmsg = nullptr;
    rc = sqlite3_exec(
        g_db,
        "CREATE TABLE IF NOT EXISTS kv (k TEXT PRIMARY KEY NOT NULL, v TEXT NOT NULL)",
        nullptr,
        nullptr,
        &errmsg);
    if (rc != SQLITE_OK)
    {
        qWarning() << "AppStateSqlite: schema" << (errmsg ? errmsg : sqlite3_errmsg(g_db));
        sqlite3_free(errmsg);
        sqlite3_close(g_db);
        g_db = nullptr;
        return false;
    }

    applyEmbeddedDbTuningPragmas(g_db);
    if (!ensureHandLogSchemaV1(g_db))
    {
        qWarning() << "AppStateSqlite: hand log schema migration failed";
        closeDb();
        return false;
    }

    if (!prepareKvPreparedStatements(g_db))
    {
        qWarning() << "AppStateSqlite: prepare KV statements failed" << sqlite3_errmsg(g_db);
        closeDb();
        return false;
    }

    return true;
}

void AppStateSqlite::migrateFromQSettingsIfEmpty()
{
    if (g_backend != Backend::Sqlite || !g_db)
        return;

    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(g_db, "SELECT COUNT(*) FROM kv", -1, &st, nullptr) != SQLITE_OK)
        return;
    if (sqlite3_step(st) != SQLITE_ROW)
    {
        sqlite3_finalize(st);
        return;
    }
    const sqlite3_int64 cnt = sqlite3_column_int64(st, 0);
    sqlite3_finalize(st);
    if (cnt > 0)
        return;

    QSettings legacy;
    legacy.beginGroup(QStringLiteral("v1"));
    const QStringList keys = legacy.allKeys();
    for (const QString &k : keys)
    {
        const QString full = QStringLiteral("v1/") + k;
        setValue(full, legacy.value(k));
    }
    legacy.endGroup();
    sync();
}

void AppStateSqlite::init()
{
    if (g_backend != Backend::None)
        return;

#ifndef NDEBUG
    if (!testJsonRoundTrip())
        qCritical() << "AppStateSqlite: JSON variant round-trip self-test failed (see qWarning output above)";
#endif

    const QString path = sqlitePath();
    if (path.isEmpty())
    {
        qCritical() << "AppStateSqlite: no SQLite path (empty AppLocalDataLocation); set TEXAS_HOLDEM_GYM_SQLITE";
        g_backend = Backend::QSettingsFallback;
        g_dbPath = makeFallbackSettings().fileName();
        migrateLegacyIntoFallbackIfNeeded();
        qWarning().noquote() << "AppStateSqlite: using QSettings INI fallback at" << g_dbPath;
        return;
    }

    if (tryOpenSqliteAtPath(path))
    {
        g_backend = Backend::Sqlite;
        qInfo().noquote() << "AppStateSqlite: using SQLite" << g_dbPath << "lib" << sqlite3_libversion();
        migrateFromQSettingsIfEmpty();
        cleanupNullRows();
        return;
    }

    closeDb();
    g_backend = Backend::QSettingsFallback;
    g_dbPath = makeFallbackSettings().fileName();
    migrateLegacyIntoFallbackIfNeeded();
    qWarning().noquote() << "AppStateSqlite: SQLite unavailable for" << path
                         << "- using QSettings INI fallback at" << g_dbPath
                         << "(install libsqlite3; check disk permissions)";
}

bool AppStateSqlite::isOpen()
{
    return g_backend == Backend::Sqlite || g_backend == Backend::QSettingsFallback;
}

sqlite3 *AppStateSqlite::sqliteHandle()
{
    if (g_backend != Backend::Sqlite || !g_db)
        return nullptr;
    return g_db;
}

void AppStateSqlite::resetForTesting()
{
    appStateSqliteResetForTesting();
}

QString AppStateSqlite::databasePath()
{
    return g_dbPath;
}

void AppStateSqlite::beginTransaction()
{
    if (g_backend != Backend::Sqlite || !g_db)
        return;
    /// Avoid `BEGIN` while already in a transaction (nested `savePersistedSettings`); a failed nested
    /// `BEGIN` would otherwise leave subsequent DML outside an explicit txn or in an error state.
    if (!sqlite3_get_autocommit(g_db))
        return;
    sqlite3_exec(g_db, "BEGIN", nullptr, nullptr, nullptr);
}

void AppStateSqlite::commitTransaction()
{
    if (g_backend != Backend::Sqlite || !g_db)
        return;
    if (sqlite3_get_autocommit(g_db))
        return;
    sqlite3_exec(g_db, "COMMIT", nullptr, nullptr, nullptr);
}

void AppStateSqlite::setValue(const QString &key, const QVariant &value)
{
    if (!isOpen())
        return;

    if (g_backend == Backend::QSettingsFallback)
    {
        qsettingsFallbackSetValue(key, value);
        return;
    }

    if (!g_stmt_kv_upsert)
    {
        qWarning() << "AppStateSqlite::setValue: KV upsert statement not prepared";
        return;
    }
    sqlite3_stmt *st = g_stmt_kv_upsert;
    sqlite3_reset(st);
    sqlite3_clear_bindings(st);
    const QByteArray k = key.toUtf8();
    const QByteArray json = variantToJson(value);
    sqlite3_bind_text(st, 1, k.constData(), k.size(), SQLITE_TRANSIENT);
    sqlite3_bind_text(st, 2, json.constData(), json.size(), SQLITE_TRANSIENT);

    const int stepRc = sqlite3_step(st);
    if (stepRc != SQLITE_DONE)
        qWarning() << "AppStateSqlite::setValue" << key << sqlite3_errmsg(g_db);
}

QVariant AppStateSqlite::value(const QString &key, const QVariant &defaultValue)
{
    if (!isOpen())
        return defaultValue;

    if (g_backend == Backend::QSettingsFallback)
        return qsettingsFallbackValue(key, defaultValue);

    if (!g_stmt_kv_select_v)
        return defaultValue;

    sqlite3_stmt *st = g_stmt_kv_select_v;
    sqlite3_reset(st);
    sqlite3_clear_bindings(st);
    const QByteArray k = key.toUtf8();
    sqlite3_bind_text(st, 1, k.constData(), k.size(), SQLITE_TRANSIENT);

    const int stepRc = sqlite3_step(st);
    if (stepRc != SQLITE_ROW)
        return defaultValue;

    const char *v = reinterpret_cast<const char *>(sqlite3_column_text(st, 0));
    const int nbytes = sqlite3_column_bytes(st, 0);

    if (!v || nbytes < 0)
        return defaultValue;
    const QByteArray jsonBytes(v, nbytes);

    QVariant out;
    if (!jsonToVariant(jsonBytes, &out))
        return defaultValue;
    if (!out.isValid())
        return defaultValue;
    return out;
}

bool AppStateSqlite::contains(const QString &key)
{
    if (!isOpen())
        return false;

    if (g_backend == Backend::QSettingsFallback)
        return qsettingsFallbackContains(key);

    if (!g_stmt_kv_exists)
        return false;

    sqlite3_stmt *st = g_stmt_kv_exists;
    sqlite3_reset(st);
    sqlite3_clear_bindings(st);
    const QByteArray k = key.toUtf8();
    sqlite3_bind_text(st, 1, k.constData(), k.size(), SQLITE_TRANSIENT);
    return sqlite3_step(st) == SQLITE_ROW;
}

void AppStateSqlite::clearHandLogTables()
{
    if (!g_db || g_backend != Backend::Sqlite)
        return;
    char *err = nullptr;
    sqlite3_exec(g_db, "DELETE FROM actions", nullptr, nullptr, &err);
    sqlite3_free(err);
    err = nullptr;
    sqlite3_exec(g_db, "DELETE FROM hands", nullptr, nullptr, &err);
    sqlite3_free(err);
    err = nullptr;
    sqlite3_exec(g_db, "DELETE FROM players", nullptr, nullptr, &err);
    sqlite3_free(err);
}

void AppStateSqlite::removeKeysWithPrefix(const QString &prefix)
{
    if (!isOpen() || prefix.isEmpty())
        return;

    if (g_backend == Backend::QSettingsFallback)
    {
        qsettingsFallbackRemovePrefix(prefix);
        return;
    }

    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(g_db, "DELETE FROM kv WHERE k LIKE ?", -1, &st, nullptr) != SQLITE_OK)
    {
        qWarning() << "AppStateSqlite::removeKeysWithPrefix prepare" << sqlite3_errmsg(g_db);
        return;
    }

    const QString like = prefix + QLatin1Char('%');
    const QByteArray pat = like.toUtf8();
    sqlite3_bind_text(st, 1, pat.constData(), pat.size(), SQLITE_TRANSIENT);
    const int stepRc = sqlite3_step(st);
    sqlite3_finalize(st);
    if (stepRc != SQLITE_DONE)
        qWarning() << "AppStateSqlite::removeKeysWithPrefix" << prefix << sqlite3_errmsg(g_db);
}

void AppStateSqlite::sync()
{
    if (g_backend == Backend::QSettingsFallback)
    {
        QSettings s = makeFallbackSettings();
        s.sync();
        return;
    }
    if (g_db)
        sqlite3_db_cacheflush(g_db);
}

QByteArray AppStateSqlite::testVariantToJson(const QVariant &v) { return variantToJson(v); }

bool AppStateSqlite::testJsonToVariant(const QByteArray &json, QVariant *out) { return jsonToVariant(json, out); }
