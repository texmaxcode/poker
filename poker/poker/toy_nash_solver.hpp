#ifndef TEXAS_HOLDEM_GYM_TOY_NASH_SOLVER_H
#define TEXAS_HOLDEM_GYM_TOY_NASH_SOLVER_H

#include <QObject>
#include <QVariantMap>

#include <atomic>

/// CFR+ Nash-equilibrium solver for small poker benchmarks (Kuhn / Leduc).
/// This provides a correct foundation that can later be extended to larger hold'em abstractions.
class ToyNashSolver : public QObject
{
    Q_OBJECT

public:
    explicit ToyNashSolver(QObject *parent = nullptr);

    /// Solve Kuhn poker (3-card) via CFR+; returns EV and average strategies. Runs on a worker thread.
    Q_INVOKABLE void solveKuhnAsync(int iterations);

    /// Solve Leduc hold'em (6-card, 1 public card) via CFR+; returns EV and average strategies.
    Q_INVOKABLE QVariantMap solveLeduc(int iterations) const;
    Q_INVOKABLE void solveLeducAsync(int iterations);

    Q_INVOKABLE bool solveRunning() const { return async_busy_.load(); }

signals:
    void solveFinished(const QVariantMap &result);

private:
    std::atomic<bool> async_busy_{false};
};

#endif // TEXAS_HOLDEM_GYM_TOY_NASH_SOLVER_H

