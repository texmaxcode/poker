#ifndef TEXAS_HOLDEM_GYM_HAND_LOG_STORE_HPP
#define TEXAS_HOLDEM_GYM_HAND_LOG_STORE_HPP

#include <QtGlobal>

#include <memory>

/// Integer codes for `actions.action_kind` (avoid string enums in the DB).
namespace HandLogAction
{
constexpr int kFold = 0;
constexpr int kCheck = 1;
constexpr int kCall = 2;
constexpr int kBet = 3;
constexpr int kRaise = 4;
constexpr int kAllIn = 5;
} // namespace HandLogAction

/// Integer codes for `actions.street`.
namespace HandLogStreet
{
constexpr int kPreflop = 0;
constexpr int kFlop = 1;
constexpr int kTurn = 2;
constexpr int kRiver = 3;
constexpr int kShowdown = 4;
} // namespace HandLogStreet

/// Batched hand/action logging on the same SQLite connection as `AppStateSqlite`.
///
/// Uses `sqlite3_prepare_v2` + bound parameters and a single `BEGIN IMMEDIATE` … `COMMIT`
/// transaction (equivalent to the “`QSqlQuery::prepare` + batch + one commit” pattern).
///
/// Do not construct while another explicit transaction is open on the app store unless
/// you coordinate with `AppStateSqlite::beginTransaction` / `commitTransaction`.
class HandLogBatch
{
public:
    HandLogBatch();
    ~HandLogBatch();

    HandLogBatch(const HandLogBatch &) = delete;
    HandLogBatch &operator=(const HandLogBatch &) = delete;
    HandLogBatch(HandLogBatch &&) noexcept;
    HandLogBatch &operator=(HandLogBatch &&) noexcept;

    [[nodiscard]] bool isActive() const;

    void commit();
    void rollback();

    /// Stable integer key for a player (seat hash, user id, etc.). Inserts at most once per key per batch DB.
    [[nodiscard]] qint64 upsertPlayerByKey(qint64 player_key, qint64 created_ms = 0);

    [[nodiscard]] qint64 insertHand(qint64 started_ms,
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
                                      qint64 result_flags);

    void insertAction(qint64 hand_id,
                      int seq,
                      qint64 player_id,
                      int street,
                      int action_kind,
                      int size_chips,
                      int facing_size,
                      int extra);

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

#endif
