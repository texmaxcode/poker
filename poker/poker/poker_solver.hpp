#ifndef TEXAS_HOLDEM_GYM_POKER_SOLVER_H
#define TEXAS_HOLDEM_GYM_POKER_SOLVER_H

#include <QObject>
#include <QString>
#include <QVariantMap>

#include <atomic>

/// UI-facing equity + chip-EV / pot-odds helper (Monte Carlo).
/// This is not an equilibrium solver for no-limit hold'em; it estimates showdown equity vs a range
/// or exact hand and compares to simple pot-odds / chip-EV calling models.
class PokerSolver : public QObject
{
    Q_OBJECT

public:
    explicit PokerSolver(QObject *parent = nullptr);

    /// Hero cards like "Ah" "Kd"; board space-separated; villain range text (same as Bots tab).
    /// If villainExact1 and villainExact2 are non-empty, ignores range and uses that hole.
    /// potBeforeCall + callAmount: if both > 0, computes break-even equity and EV of calling.
    /// Runs on the calling thread (blocks) — prefer computeEquityAsync from UI.
    Q_INVOKABLE QVariantMap computeEquity(const QString &hero1,
                                          const QString &hero2,
                                          const QString &boardSpaceSeparated,
                                          const QString &villainRangeText,
                                          const QString &villainExact1,
                                          const QString &villainExact2,
                                          int iterations,
                                          double potBeforeCall,
                                          double callAmount) const;

    /// Same inputs as computeEquity; work runs on a worker thread. Listen for equityComputationFinished.
    Q_INVOKABLE void computeEquityAsync(const QString &hero1,
                                        const QString &hero2,
                                        const QString &boardSpaceSeparated,
                                        const QString &villainRangeText,
                                        const QString &villainExact1,
                                        const QString &villainExact2,
                                        int iterations,
                                        double potBeforeCall,
                                        double callAmount);

    Q_INVOKABLE bool equityComputationRunning() const { return async_busy_.load(); }

signals:
    void equityComputationFinished(const QVariantMap &result);

private:
    std::atomic<bool> async_busy_{false};
};

#endif // TEXAS_HOLDEM_GYM_POKER_SOLVER_H
