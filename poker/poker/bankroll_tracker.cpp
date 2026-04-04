#include "bankroll_tracker.hpp"

#include "game.hpp"

#include <algorithm>

#include <QDateTime>
#include <QString>

static_assert(BankrollTracker::kMaxPlayers == game::kMaxPlayers,
              "BankrollTracker and game must agree on kMaxPlayers");

BankrollTracker::BankrollTracker(game &g, QObject *parent)
    : QObject(parent)
    , game_(g)
{
}

void BankrollTracker::record_bankroll_snapshot()
{
    std::array<int, kMaxPlayers> snap{};
    const int n = game_.players_count();
    for (int i = 0; i < n; ++i)
        snap[static_cast<size_t>(i)] = game_.table[static_cast<size_t>(i)].stack
                                        + game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)];
    bankroll_history_.push_back(snap);
    bankroll_snapshot_times_ms_.push_back(QDateTime::currentMSecsSinceEpoch());
    ++stats_seq_;
    emit sessionStatsChanged();
}

void BankrollTracker::init_bankroll_after_configure()
{
    bankroll_history_.clear();
    bankroll_snapshot_times_ms_.clear();
    const int n = game_.players_count();
    for (int i = 0; i < n; ++i)
        session_baseline_[static_cast<size_t>(i)] =
            game_.table[static_cast<size_t>(i)].stack + game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)];
    record_bankroll_snapshot();
}

void BankrollTracker::resetBankrollSession()
{
    const int n = game_.players_count();
    for (int i = 0; i < n; ++i)
        session_baseline_[static_cast<size_t>(i)] =
            game_.table[static_cast<size_t>(i)].stack + game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)];
    bankroll_history_.clear();
    bankroll_snapshot_times_ms_.clear();
    record_bankroll_snapshot();
}

QVariantList BankrollTracker::bankrollSeries(int seat) const
{
    QVariantList out;
    if (seat < 0 || seat >= kMaxPlayers)
        return out;
    const size_t si = static_cast<size_t>(seat);
    for (const auto &snap : bankroll_history_)
        out.append(snap[si]);
    return out;
}

int BankrollTracker::bankrollSnapshotCount() const
{
    return static_cast<int>(bankroll_history_.size());
}

QVariantList BankrollTracker::bankrollSnapshotTimesMs() const
{
    QVariantList out;
    for (qint64 t : bankroll_snapshot_times_ms_)
        out.append(static_cast<qlonglong>(t));
    return out;
}

QVariantList BankrollTracker::seatRankings() const
{
    struct Row
    {
        int seat;
        int table_stack;
        int wallet;
        int total;
    };
    std::vector<Row> rows;
    const int n = game_.players_count();
    rows.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i)
    {
        const int st = game_.table[static_cast<size_t>(i)].stack;
        const int w = game_.seat_mgr_.seat_wallet_[static_cast<size_t>(i)];
        rows.push_back({i, st, w, st + w});
    }
    std::sort(rows.begin(), rows.end(), [](const Row &a, const Row &b) { return a.total > b.total; });

    QVariantList out;
    int rank = 1;
    for (size_t i = 0; i < rows.size(); ++i)
    {
        if (i > 0 && rows[i].total < rows[i - 1].total)
            rank = static_cast<int>(i) + 1;
        const int seat = rows[i].seat;
        QVariantMap m;
        m[QStringLiteral("seat")] = seat;
        m[QStringLiteral("stack")] = rows[i].table_stack;
        m[QStringLiteral("wallet")] = rows[i].wallet;
        m[QStringLiteral("total")] = rows[i].total;
        m[QStringLiteral("rank")] = rank;
        m[QStringLiteral("profit")] = rows[i].total - session_baseline_[static_cast<size_t>(seat)];
        out.append(m);
    }
    return out;
}

int BankrollTracker::sessionBaselineStack(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    return session_baseline_[static_cast<size_t>(seat)];
}

void BankrollTracker::notifySessionStatsChanged()
{
    ++stats_seq_;
    emit sessionStatsChanged();
}
