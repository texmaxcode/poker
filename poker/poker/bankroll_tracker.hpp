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

    QVariantList bankrollSeries(int seat) const;
    int bankrollSnapshotCount() const;
    QVariantList bankrollSnapshotTimesMs() const;
    QVariantList seatRankings() const;
    int sessionBaselineStack(int seat) const;

    void notifySessionStatsChanged();
    int statsSeq() const { return stats_seq_; }

signals:
    void sessionStatsChanged();

private:
    game &game_;
    std::vector<std::array<int, kMaxPlayers>> bankroll_history_;
    std::vector<qint64> bankroll_snapshot_times_ms_;
    std::array<int, kMaxPlayers> session_baseline_{};
    int stats_seq_ = 0;
};

#endif // BANKROLL_TRACKER_HPP
