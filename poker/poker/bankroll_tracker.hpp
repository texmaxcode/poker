#ifndef BANKROLL_TRACKER_HPP
#define BANKROLL_TRACKER_HPP

#include <array>
#include <vector>

#include <QObject>
#include <QtGlobal>
#include <QVariantList>
#include <QVariantMap>

class game;
class GamePersistence;

class BankrollTracker : public QObject
{
    Q_OBJECT
    friend class GamePersistence;

public:
    static constexpr int kMaxPlayers = 6;

    explicit BankrollTracker(game &g, QObject *parent = nullptr);

    void record_bankroll_snapshot();
    void init_bankroll_after_configure();
    void resetBankrollSession();

    /// Total chips per snapshot (on-table stack + off-table wallet).
    QVariantList bankrollSeries(int seat) const;
    /// On-table stack only — used for P/L and the stats chart (wallet moves do not affect this series).
    QVariantList tableStackSeries(int seat) const;
    int bankrollSnapshotCount() const;
    QVariantList bankrollSnapshotTimesMs() const;
    QVariantList seatRankings() const;
    /// Session baseline: total chips (stack + wallet) at last reset / configure.
    int sessionBaselineStack(int seat) const;
    /// Session baseline: on-table stack only (P/L at the table is vs this).
    int sessionBaselineTableStack(int seat) const;

    void notifySessionStatsChanged();
    int statsSeq() const { return stats_seq_; }

signals:
    void sessionStatsChanged();

private:
    game &game_;
    std::vector<std::array<int, kMaxPlayers>> bankroll_history_;
    std::vector<std::array<int, kMaxPlayers>> table_stack_history_;
    std::vector<qint64> bankroll_snapshot_times_ms_;
    std::array<int, kMaxPlayers> session_baseline_{};
    std::array<int, kMaxPlayers> session_baseline_table_{};
    int stats_seq_ = 0;
};

#endif // BANKROLL_TRACKER_HPP
