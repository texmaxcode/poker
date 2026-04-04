#ifndef HUMAN_DECISION_CONTROLLER_HPP
#define HUMAN_DECISION_CONTROLLER_HPP

#include <functional>

#include <QObject>
#include <QTimer>

class game;
enum class Street;

/// Owns human decision timers, wait-loop state, and submit/finish handlers.
/// Extracted from `game` — the nested QEventLoop pattern is preserved as-is.
class HumanDecisionController : public QObject
{
    Q_OBJECT

public:
    explicit HumanDecisionController(game &g, QObject *parent = nullptr);

    void wait_for_human_need(int need_chips, Street st, int raise_increment_chips);
    bool wait_for_human_check_or_bet(Street st);
    bool wait_for_human_bb_preflop();

    void submitFacingAction(int action, int raiseChips);
    void submitCheckOrBet(bool check, int betChips);
    void submitBbPreflopRaise(int chipsToAdd);
    void submitFoldFromCheck();

    void requestMoreTime();

    /// Resets all decision flags and stops timers (called from `game::clear_for_new_hand`).
    void reset();

    bool isWaitingForHuman() const { return waiting_for_human_; }
    bool isWaitingForHumanCheck() const { return waiting_for_human_check_; }
    bool isWaitingForHumanBbPreflop() const { return waiting_for_human_bb_preflop_; }
    int humanFacingAction() const { return human_facing_action_; }
    int humanFacingRaiseChips() const { return human_facing_raise_chips_; }
    int decisionSecondsLeft() const { return decision_seconds_left_; }
    bool humanMoreTimeAvailable() const { return human_more_time_available_; }
    int pendingHumanNeed() const { return pending_human_need_; }
    int pendingHumanRaiseInc() const { return pending_human_raise_inc_; }

    void finish_human_bb_preflop(bool raise);

signals:
    void humanDecisionFinished();
    void humanCheckFinished();
    void humanBbPreflopFinished();

private:
    void arm_decision_timers(std::function<void()> on_deadline);
    void finish_human_check(bool check, int bet_chips);

    game &game_;
    QTimer human_decision_tick_;
    QTimer human_decision_deadline_;

    int decision_seconds_left_ = 0;
    bool waiting_for_human_ = false;
    bool waiting_for_human_check_ = false;
    bool waiting_for_human_bb_preflop_ = false;
    int human_facing_action_ = -1;
    int human_facing_raise_chips_ = 0;
    bool human_opened_bet_from_check_ = false;
    bool human_bb_preflop_raised_ = false;
    bool human_more_time_available_ = false;
    int pending_human_need_ = 0;
    int pending_human_raise_inc_ = 0;
};

#endif // HUMAN_DECISION_CONTROLLER_HPP
