#ifndef TEXAS_HOLDEM_GYM_TRAINING_STORE_H
#define TEXAS_HOLDEM_GYM_TRAINING_STORE_H

#include <QObject>
#include <QVariantMap>

/// Persists trainer progress / mistake aggregates in the app SQLite store (`AppStateSqlite`).
/// Keys live under `v1/training/*`.
class TrainingStore : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int trainerAutoAdvanceMs READ trainerAutoAdvanceMs WRITE setTrainerAutoAdvanceMs NOTIFY trainerAutoAdvanceMsChanged)
    Q_PROPERTY(int trainerDecisionSeconds READ trainerDecisionSeconds WRITE setTrainerDecisionSeconds NOTIFY trainerDecisionSecondsChanged)

public:
    explicit TrainingStore(QObject *parent = nullptr);

    /// Delay after answering before the next trainer hand (default 5000 ms). Clamped in the setter.
    int trainerAutoAdvanceMs() const;
    void setTrainerAutoAdvanceMs(int ms);

    /// Seconds to answer each drill question (default 20). Clamped in the setter.
    int trainerDecisionSeconds() const;
    void setTrainerDecisionSeconds(int sec);

    /// Load all progress fields needed by the dashboard.
    Q_INVOKABLE QVariantMap loadProgress() const;
    /// Record a scored decision event.
    /// Expected keys:
    /// - position: "UTG|MP|CO|BTN|SB|BB" (optional)
    /// - street: "preflop|flop|turn|river" (optional)
    /// - spotId: string identifier for drill/spot (optional)
    /// - correct: bool (optional; defaults false)
    /// - evLossBb: double (optional; defaults 0)
    Q_INVOKABLE void recordDecision(const QVariantMap &event);
    /// Clears all training progress.
    Q_INVOKABLE void resetProgress();

signals:
    void progressChanged();
    void trainerAutoAdvanceMsChanged();
    void trainerDecisionSecondsChanged();

private:
    static constexpr int kSchemaVersion = 1;
};

#endif // TEXAS_HOLDEM_GYM_TRAINING_STORE_H

