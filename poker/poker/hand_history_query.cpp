#include "hand_history_query.hpp"

#include "cards.hpp"
#include "hand_log_store.hpp"
#include "persist_sqlite.hpp"

#include <QString>
#include <QStringList>
#include <QtGlobal>

#include <sqlite3.h>

namespace {

QString decode_card_display(int code)
{
    if (code < 0 || code > 51)
        return {};
    const int rank = code / 4; // 0..12 == TWO..ACE
    const int suite = code % 4; // 0..3 == CLUBS..SPADES (matches Suite enum order for encoding)
    card c(static_cast<Rank>(rank + 2), static_cast<Suite>(suite + 1));
    return card_to_display_string(c);
}

QString decode_card_asset(int code)
{
    if (code < 0 || code > 51)
        return {};
    const int rank = code / 4;
    const int suite = code % 4;
    card c(static_cast<Rank>(rank + 2), static_cast<Suite>(suite + 1));
    return card_to_qml_asset_path(c);
}

QVariantList winners_from_flags(qint64 flags)
{
    QVariantList out;
    for (int s = 0; s < 64; ++s)
    {
        if ((flags >> s) & 0x1)
            out.append(s);
    }
    return out;
}

QString action_kind_label(int kind)
{
    switch (kind)
    {
    case HandLogAction::kFold:
        return QStringLiteral("Fold");
    case HandLogAction::kCheck:
        return QStringLiteral("Check");
    case HandLogAction::kCall:
        return QStringLiteral("Call");
    case HandLogAction::kBet:
        return QStringLiteral("Bet");
    case HandLogAction::kRaise:
        return QStringLiteral("Raise");
    case HandLogAction::kAllIn:
        return QStringLiteral("All-in");
    }
    return QStringLiteral("?");
}

int count_actions_for_hand(sqlite3 *db, sqlite3_int64 hand_id)
{
    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM actions WHERE hand_id = ?", -1, &st, nullptr) != SQLITE_OK)
        return 0;
    sqlite3_bind_int64(st, 1, hand_id);
    int out = 0;
    if (sqlite3_step(st) == SQLITE_ROW)
        out = sqlite3_column_int(st, 0);
    sqlite3_finalize(st);
    return out;
}

QVariantMap row_to_map(sqlite3_stmt *st, sqlite3 *db)
{
    QVariantMap m;
    const sqlite3_int64 id = sqlite3_column_int64(st, 0);
    m.insert(QStringLiteral("id"), static_cast<qlonglong>(id));
    m.insert(QStringLiteral("startedMs"), static_cast<qlonglong>(sqlite3_column_int64(st, 1)));
    m.insert(QStringLiteral("endedMs"), static_cast<qlonglong>(sqlite3_column_int64(st, 2)));
    m.insert(QStringLiteral("buttonSeat"), sqlite3_column_int(st, 3));
    m.insert(QStringLiteral("sbSeat"), sqlite3_column_int(st, 4));
    m.insert(QStringLiteral("bbSeat"), sqlite3_column_int(st, 5));
    m.insert(QStringLiteral("numPlayers"), sqlite3_column_int(st, 6));
    m.insert(QStringLiteral("sbSize"), sqlite3_column_int(st, 7));
    m.insert(QStringLiteral("bbSize"), sqlite3_column_int(st, 8));

    QStringList disp;
    QStringList assets;
    for (int i = 0; i < 5; ++i)
    {
        const int code = sqlite3_column_int(st, 9 + i);
        if (code < 0)
            break;
        const QString d = decode_card_display(code);
        const QString a = decode_card_asset(code);
        if (!d.isEmpty())
        {
            disp.append(d);
            assets.append(a);
        }
    }
    m.insert(QStringLiteral("boardDisplay"), disp.join(QLatin1Char(' ')));
    m.insert(QStringLiteral("boardAssets"), QVariant::fromValue(assets));

    const qint64 flags = sqlite3_column_int64(st, 14);
    m.insert(QStringLiteral("winners"), winners_from_flags(flags));
    m.insert(QStringLiteral("actionCount"), count_actions_for_hand(db, id));
    return m;
}

constexpr const char *kSelectHandCols =
    "id, started_ms, ended_ms, button_seat, sb_seat, bb_seat, num_players, sb_size, bb_size, "
    "board_c0, board_c1, board_c2, board_c3, board_c4, result_flags";

} // namespace

HandHistoryQuery::HandHistoryQuery(QObject *parent)
    : QObject(parent)
{
}

QVariantList HandHistoryQuery::listRecent(int limit, int offset) const
{
    QVariantList out;
    sqlite3 *db = AppStateSqlite::sqliteHandle();
    if (!db)
        return out;
    if (limit < 1)
        limit = 50;
    if (offset < 0)
        offset = 0;

    const QString sql = QStringLiteral("SELECT %1 FROM hands ORDER BY started_ms DESC LIMIT ? OFFSET ?")
                            .arg(QLatin1String(kSelectHandCols));
    const QByteArray sqlUtf8 = sql.toUtf8();

    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(db, sqlUtf8.constData(), -1, &st, nullptr) != SQLITE_OK)
        return out;
    sqlite3_bind_int(st, 1, limit);
    sqlite3_bind_int(st, 2, offset);
    while (sqlite3_step(st) == SQLITE_ROW)
        out.append(row_to_map(st, db));
    sqlite3_finalize(st);
    return out;
}

int HandHistoryQuery::countHands() const
{
    sqlite3 *db = AppStateSqlite::sqliteHandle();
    if (!db)
        return 0;
    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM hands", -1, &st, nullptr) != SQLITE_OK)
        return 0;
    int n = 0;
    if (sqlite3_step(st) == SQLITE_ROW)
        n = sqlite3_column_int(st, 0);
    sqlite3_finalize(st);
    return n;
}

QVariantMap HandHistoryQuery::hand(qint64 handId) const
{
    QVariantMap out;
    sqlite3 *db = AppStateSqlite::sqliteHandle();
    if (!db)
        return out;

    const QString sql = QStringLiteral("SELECT %1 FROM hands WHERE id = ? LIMIT 1")
                            .arg(QLatin1String(kSelectHandCols));
    const QByteArray sqlUtf8 = sql.toUtf8();
    sqlite3_stmt *st = nullptr;
    if (sqlite3_prepare_v2(db, sqlUtf8.constData(), -1, &st, nullptr) != SQLITE_OK)
        return out;
    sqlite3_bind_int64(st, 1, static_cast<sqlite3_int64>(handId));
    if (sqlite3_step(st) == SQLITE_ROW)
        out = row_to_map(st, db);
    sqlite3_finalize(st);
    if (out.isEmpty())
        return out;

    QVariantList actions;
    sqlite3_stmt *sa = nullptr;
    if (sqlite3_prepare_v2(
            db,
            "SELECT a.seq, a.street, a.action_kind, a.size_chips, a.facing_size, a.extra, p.player_key "
            "FROM actions a JOIN players p ON p.id = a.player_id "
            "WHERE a.hand_id = ? ORDER BY a.seq",
            -1,
            &sa,
            nullptr)
        == SQLITE_OK)
    {
        sqlite3_bind_int64(sa, 1, static_cast<sqlite3_int64>(handId));
        while (sqlite3_step(sa) == SQLITE_ROW)
        {
            QVariantMap m;
            m.insert(QStringLiteral("seq"), sqlite3_column_int(sa, 0));
            const int street = sqlite3_column_int(sa, 1);
            m.insert(QStringLiteral("street"), street);
            const int kind = sqlite3_column_int(sa, 2);
            m.insert(QStringLiteral("kind"), kind);
            m.insert(QStringLiteral("kindLabel"), action_kind_label(kind));
            m.insert(QStringLiteral("chips"), sqlite3_column_int(sa, 3));
            m.insert(QStringLiteral("facing"), sqlite3_column_int(sa, 4));
            const int extra = sqlite3_column_int(sa, 5);
            m.insert(QStringLiteral("extra"), extra);
            m.insert(QStringLiteral("isBlind"), (extra & 0x1) ? true : false);
            const qint64 pkey = sqlite3_column_int64(sa, 6);
            m.insert(QStringLiteral("seat"), static_cast<int>(pkey % 64));
            actions.append(m);
        }
        sqlite3_finalize(sa);
    }
    out.insert(QStringLiteral("actions"), actions);
    return out;
}

void HandHistoryQuery::notifyHistoryChanged()
{
    emit historyChanged();
}

void HandHistoryQuery::clearAll()
{
    sqlite3 *db = AppStateSqlite::sqliteHandle();
    if (!db)
        return;
    char *err = nullptr;
    sqlite3_exec(db, "DELETE FROM actions", nullptr, nullptr, &err);
    sqlite3_free(err);
    err = nullptr;
    sqlite3_exec(db, "DELETE FROM hands", nullptr, nullptr, &err);
    sqlite3_free(err);
    err = nullptr;
    sqlite3_exec(db, "DELETE FROM players", nullptr, nullptr, &err);
    sqlite3_free(err);
    emit historyChanged();
}
