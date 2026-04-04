#ifndef TEXAS_HOLDEM_GYM_TRAINING_CONTROLLER_H
#define TEXAS_HOLDEM_GYM_TRAINING_CONTROLLER_H

#include <QObject>
#include <QStringList>
#include <QVariantMap>

#include <array>
#include <random>
#include <string>
#include <unordered_map>
#include <vector>

class TrainingStore;
class card;

/// Generates trainer questions (preflop ranges, postflop spots) and scores user answers.
/// V1: preflop open ranges by position.
class TrainingController : public QObject
{
    Q_OBJECT

public:
    explicit TrainingController(TrainingStore *store, QObject *parent = nullptr);

    Q_INVOKABLE bool loadPreflopRanges(const QString &qrcUrl);
    Q_INVOKABLE bool loadFlopSpots(const QString &qrcUrl);
    Q_INVOKABLE bool loadTurnSpots(const QString &qrcUrl);
    Q_INVOKABLE bool loadRiverSpots(const QString &qrcUrl);

    /// Modes present in the loaded JSON for this position (e.g. "open", "vs3bet").
    Q_INVOKABLE QStringList preflopModesForPosition(const QString &position) const;

    Q_INVOKABLE void startPreflopDrill(const QString &position, const QString &mode);
    Q_INVOKABLE QVariantMap nextPreflopQuestion();
    Q_INVOKABLE QVariantMap submitPreflopAnswer(const QString &action, int raiseSizeBb);

    Q_INVOKABLE void startFlopDrill(const QString &matchup);
    Q_INVOKABLE QVariantMap nextFlopQuestion();
    Q_INVOKABLE QVariantMap submitFlopAnswer(const QString &action);

    Q_INVOKABLE void startTurnDrill(const QString &matchup);
    Q_INVOKABLE QVariantMap nextTurnQuestion();
    Q_INVOKABLE QVariantMap submitTurnAnswer(const QString &action);

    Q_INVOKABLE void startRiverDrill(const QString &matchup);
    Q_INVOKABLE QVariantMap nextRiverQuestion();
    Q_INVOKABLE QVariantMap submitRiverAnswer(const QString &action);

    QVariantMap lastFeedback() const { return last_feedback_; }

signals:
    void lastFeedbackChanged();

private:
    struct Scenario
    {
        QString position;
        QString mode;
        std::array<double, 169> fold{};
        std::array<double, 169> call{};
        std::array<double, 169> raise{};
        bool loaded = false;
    };

    TrainingStore *store_ = nullptr;
    std::mt19937 rng_{std::random_device{}()};

    // key: "POS|MODE" e.g. "BTN|open"
    std::unordered_map<std::string, Scenario> scenarios_;

    /// Postflop (flop / turn / river) spot: `board` holds 3–5 card asset names; `n_board` is the street.
    struct PostflopSpot
    {
        QString id;
        std::array<QString, 5> board{};
        int n_board = 3;
        QString hero1;
        QString hero2;
        double freq_check = 0.0;
        double freq_b33 = 0.0;
        double freq_b75 = 0.0;
        double ev_check = 0.0;
        double ev_b33 = 0.0;
        double ev_b75 = 0.0;
    };

    std::vector<PostflopSpot> flop_spots_;
    int flop_idx_ = -1;
    std::vector<PostflopSpot> turn_spots_;
    int turn_idx_ = -1;
    std::vector<PostflopSpot> river_spots_;
    int river_idx_ = -1;

    QString cur_position_;
    QString cur_mode_;
    int cur_hand_idx_ = -1; // 0..168
    QString cur_card1_;
    QString cur_card2_;

    QVariantMap last_feedback_;

    static int hand_index_from_cards(const card &a, const card &b);
    static std::string scenario_key(const QString &pos, const QString &mode);
    const Scenario *current_scenario() const;

    bool loadPostflopSpotsFromUrl(const QString &qrcUrl, int expected_board, std::vector<PostflopSpot> &out);
    QVariantMap nextPostflopQuestion(std::vector<PostflopSpot> &spots, int &idx, const QString &empty_err);
    QVariantMap submitPostflopAnswer(const QString &action, const std::vector<PostflopSpot> &spots, int idx,
                                     const QString &street);
};

#endif // TEXAS_HOLDEM_GYM_TRAINING_CONTROLLER_H

