#include "hand_log_store.hpp"

#include "persist_sqlite.hpp"

#include <QDateTime>

#include <sqlite3.h>

struct HandLogBatch::Impl
{
    sqlite3 *db = nullptr;
    bool owns_txn = false;
    bool finished = false;

    sqlite3_stmt *st_ins_player = nullptr;
    sqlite3_stmt *st_sel_player = nullptr;
    sqlite3_stmt *st_ins_hand = nullptr;
    sqlite3_stmt *st_ins_action = nullptr;

    void finalizeAll()
    {
        if (st_ins_player)
        {
            sqlite3_finalize(st_ins_player);
            st_ins_player = nullptr;
        }
        if (st_sel_player)
        {
            sqlite3_finalize(st_sel_player);
            st_sel_player = nullptr;
        }
        if (st_ins_hand)
        {
            sqlite3_finalize(st_ins_hand);
            st_ins_hand = nullptr;
        }
        if (st_ins_action)
        {
            sqlite3_finalize(st_ins_action);
            st_ins_action = nullptr;
        }
    }

    bool prepareAll()
    {
        if (sqlite3_prepare_v2(db,
                               "INSERT INTO players (created_ms, player_key) VALUES (?, ?) "
                               "ON CONFLICT(player_key) DO NOTHING",
                               -1,
                               &st_ins_player,
                               nullptr) != SQLITE_OK)
            return false;
        if (sqlite3_prepare_v2(db,
                               "SELECT id FROM players WHERE player_key = ? LIMIT 1",
                               -1,
                               &st_sel_player,
                               nullptr) != SQLITE_OK)
            return false;
        if (sqlite3_prepare_v2(
                db,
                "INSERT INTO hands (started_ms, ended_ms, session_key, button_seat, sb_seat, bb_seat, "
                "num_players, sb_size, bb_size, board_c0, board_c1, board_c2, board_c3, board_c4, result_flags) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                -1,
                &st_ins_hand,
                nullptr) != SQLITE_OK)
            return false;
        if (sqlite3_prepare_v2(
                db,
                "INSERT INTO actions (hand_id, seq, player_id, street, action_kind, size_chips, facing_size, extra) "
                "VALUES (?,?,?,?,?,?,?,?)",
                -1,
                &st_ins_action,
                nullptr) != SQLITE_OK)
            return false;
        return true;
    }
};

HandLogBatch::HandLogBatch()
    : impl_(std::make_unique<Impl>())
{
    sqlite3 *db = AppStateSqlite::sqliteHandle();
    if (!db)
        return;
    if (!sqlite3_get_autocommit(db))
    {
        qWarning() << "HandLogBatch: SQLite connection is already inside a transaction; refusing to nest";
        return;
    }
    char *err = nullptr;
    if (sqlite3_exec(db, "BEGIN IMMEDIATE", nullptr, nullptr, &err) != SQLITE_OK)
    {
        qWarning() << "HandLogBatch: BEGIN failed:" << (err ? err : sqlite3_errmsg(db));
        sqlite3_free(err);
        return;
    }
    impl_->db = db;
    impl_->owns_txn = true;
    if (!impl_->prepareAll())
    {
        qWarning() << "HandLogBatch: prepare failed:" << sqlite3_errmsg(db);
        sqlite3_exec(db, "ROLLBACK", nullptr, nullptr, nullptr);
        impl_->finalizeAll();
        impl_->owns_txn = false;
        impl_->db = nullptr;
    }
}

HandLogBatch::~HandLogBatch()
{
    if (!impl_)
        return;
    if (impl_->owns_txn && !impl_->finished && impl_->db)
        rollback();
    impl_->finalizeAll();
}

HandLogBatch::HandLogBatch(HandLogBatch &&) noexcept = default;
HandLogBatch &HandLogBatch::operator=(HandLogBatch &&) noexcept = default;

bool HandLogBatch::isActive() const
{
    return impl_ && impl_->db && impl_->owns_txn && !impl_->finished && impl_->st_ins_action;
}

void HandLogBatch::commit()
{
    if (!impl_ || !impl_->db || !impl_->owns_txn || impl_->finished)
        return;
    impl_->finalizeAll();
    char *err = nullptr;
    if (sqlite3_exec(impl_->db, "COMMIT", nullptr, nullptr, &err) != SQLITE_OK)
    {
        qWarning() << "HandLogBatch: COMMIT failed:" << (err ? err : sqlite3_errmsg(impl_->db));
        sqlite3_free(err);
    }
    impl_->owns_txn = false;
    impl_->finished = true;
}

void HandLogBatch::rollback()
{
    if (!impl_ || !impl_->db || !impl_->owns_txn || impl_->finished)
        return;
    impl_->finalizeAll();
    char *err = nullptr;
    if (sqlite3_exec(impl_->db, "ROLLBACK", nullptr, nullptr, &err) != SQLITE_OK)
    {
        qWarning() << "HandLogBatch: ROLLBACK failed:" << (err ? err : sqlite3_errmsg(impl_->db));
        sqlite3_free(err);
    }
    impl_->owns_txn = false;
    impl_->finished = true;
}

qint64 HandLogBatch::upsertPlayerByKey(qint64 player_key, qint64 created_ms)
{
    if (!isActive())
        return 0;
    const qint64 ts =
        (created_ms > 0) ? created_ms : QDateTime::currentMSecsSinceEpoch();
    sqlite3_stmt *ins = impl_->st_ins_player;
    sqlite3_reset(ins);
    sqlite3_clear_bindings(ins);
    sqlite3_bind_int64(ins, 1, static_cast<sqlite3_int64>(ts));
    sqlite3_bind_int64(ins, 2, static_cast<sqlite3_int64>(player_key));
    if (sqlite3_step(ins) != SQLITE_DONE)
    {
        qWarning() << "HandLogBatch::upsertPlayerByKey insert" << sqlite3_errmsg(impl_->db);
        return 0;
    }
    sqlite3_stmt *sel = impl_->st_sel_player;
    sqlite3_reset(sel);
    sqlite3_clear_bindings(sel);
    sqlite3_bind_int64(sel, 1, static_cast<sqlite3_int64>(player_key));
    if (sqlite3_step(sel) != SQLITE_ROW)
    {
        qWarning() << "HandLogBatch::upsertPlayerByKey select" << sqlite3_errmsg(impl_->db);
        return 0;
    }
    return static_cast<qint64>(sqlite3_column_int64(sel, 0));
}

qint64 HandLogBatch::insertHand(qint64 started_ms,
                                qint64 ended_ms,
                                qint64 session_key,
                                int button_seat,
                                int sb_seat,
                                int bb_seat,
                                int num_players,
                                int sb_size,
                                int bb_size,
                                int board_c0,
                                int board_c1,
                                int board_c2,
                                int board_c3,
                                int board_c4,
                                qint64 result_flags)
{
    if (!isActive())
        return 0;
    sqlite3_stmt *st = impl_->st_ins_hand;
    sqlite3_reset(st);
    sqlite3_clear_bindings(st);
    sqlite3_bind_int64(st, 1, static_cast<sqlite3_int64>(started_ms));
    sqlite3_bind_int64(st, 2, static_cast<sqlite3_int64>(ended_ms));
    sqlite3_bind_int64(st, 3, static_cast<sqlite3_int64>(session_key));
    sqlite3_bind_int(st, 4, button_seat);
    sqlite3_bind_int(st, 5, sb_seat);
    sqlite3_bind_int(st, 6, bb_seat);
    sqlite3_bind_int(st, 7, num_players);
    sqlite3_bind_int(st, 8, sb_size);
    sqlite3_bind_int(st, 9, bb_size);
    sqlite3_bind_int(st, 10, board_c0);
    sqlite3_bind_int(st, 11, board_c1);
    sqlite3_bind_int(st, 12, board_c2);
    sqlite3_bind_int(st, 13, board_c3);
    sqlite3_bind_int(st, 14, board_c4);
    sqlite3_bind_int64(st, 15, static_cast<sqlite3_int64>(result_flags));
    if (sqlite3_step(st) != SQLITE_DONE)
    {
        qWarning() << "HandLogBatch::insertHand" << sqlite3_errmsg(impl_->db);
        return 0;
    }
    return static_cast<qint64>(sqlite3_last_insert_rowid(impl_->db));
}

void HandLogBatch::insertAction(qint64 hand_id,
                                int seq,
                                qint64 player_id,
                                int street,
                                int action_kind,
                                int size_chips,
                                int facing_size,
                                int extra)
{
    if (!isActive())
        return;
    sqlite3_stmt *st = impl_->st_ins_action;
    sqlite3_reset(st);
    sqlite3_clear_bindings(st);
    sqlite3_bind_int64(st, 1, static_cast<sqlite3_int64>(hand_id));
    sqlite3_bind_int(st, 2, seq);
    sqlite3_bind_int64(st, 3, static_cast<sqlite3_int64>(player_id));
    sqlite3_bind_int(st, 4, street);
    sqlite3_bind_int(st, 5, action_kind);
    sqlite3_bind_int(st, 6, size_chips);
    sqlite3_bind_int(st, 7, facing_size);
    sqlite3_bind_int(st, 8, extra);
    if (sqlite3_step(st) != SQLITE_DONE)
        qWarning() << "HandLogBatch::insertAction" << sqlite3_errmsg(impl_->db);
}
