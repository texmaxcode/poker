#include "human_decision_controller.hpp"

#include "game.hpp"

#include <algorithm>

#include <QCoreApplication>
#include <QEventLoop>
#include <QString>
#include <QTimer>

namespace {

constexpr int kDecisionSeconds = 20;
constexpr int kMoreTimeExtraSeconds = 20;
constexpr int kMaxDecisionSecondsCap = 120;

} // namespace

HumanDecisionController::HumanDecisionController(game &g, QObject *parent)
    : QObject(parent)
    , game_(g)
    , human_decision_tick_(this)
    , human_decision_deadline_(this)
{
}

void HumanDecisionController::reset()
{
    waiting_for_human_ = false;
    waiting_for_human_check_ = false;
    waiting_for_human_bb_preflop_ = false;
    decision_seconds_left_ = 0;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
}

void HumanDecisionController::arm_decision_timers(std::function<void()> on_deadline)
{
    human_decision_tick_.disconnect();
    human_decision_deadline_.disconnect();
    human_decision_tick_.setInterval(1000);
    human_decision_tick_.setSingleShot(false);
    human_decision_deadline_.setSingleShot(true);
    human_decision_deadline_.setInterval(kDecisionSeconds * 1000);

    QObject::connect(&human_decision_tick_, &QTimer::timeout, this, [this]() {
        if (decision_seconds_left_ > 0)
        {
            --decision_seconds_left_;
            game_.sync_ui();
        }
    });
    QObject::connect(&human_decision_deadline_, &QTimer::timeout, this,
                     [fn = std::move(on_deadline)]() mutable { fn(); });
}

void HumanDecisionController::requestMoreTime()
{
    if ((!waiting_for_human_ && !waiting_for_human_check_ && !waiting_for_human_bb_preflop_) ||
        !game_.m_root || !human_more_time_available_)
        return;
    human_more_time_available_ = false;
    decision_seconds_left_ =
        std::min(decision_seconds_left_ + kMoreTimeExtraSeconds, kMaxDecisionSecondsCap);
    human_decision_deadline_.stop();
    human_decision_deadline_.setSingleShot(true);
    human_decision_deadline_.setInterval(decision_seconds_left_ * 1000);
    human_decision_deadline_.start();
    game_.sync_ui();
}

void HumanDecisionController::wait_for_human_need(int need_chips, Street st, int raise_increment_chips)
{
    (void)st;

    if (!game_.m_root)
        return;
    if (need_chips <= 0)
        return;

    const size_t hi = static_cast<size_t>(game::kHumanSeat);
    if (game_.table[hi].stack <= 0)
    {
        human_facing_action_ = 1;
        human_facing_raise_chips_ = 0;
        pending_human_need_ = 0;
        pending_human_raise_inc_ = raise_increment_chips;
        game_.sync_ui();
        return;
    }

    pending_human_need_ =
        std::min(need_chips, std::max(0, game_.table[static_cast<size_t>(game::kHumanSeat)].stack));
    pending_human_raise_inc_ = raise_increment_chips;
    waiting_for_human_ = true;
    human_facing_action_ = -1;
    human_facing_raise_chips_ = 0;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

    arm_decision_timers([this]() { submitFacingAction(0, 0); });
    game_.sync_ui();

    if (game_.human_sitting_out_)
    {
        submitFacingAction(0, 0);
        return;
    }

    human_decision_tick_.start();
    human_decision_deadline_.start();
    game_.sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &HumanDecisionController::humanDecisionFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();
}

void HumanDecisionController::submitFacingAction(int action, int raiseChips)
{
    if (!waiting_for_human_)
        return;
    human_facing_action_ = action;
    human_facing_raise_chips_ = std::max(0, raiseChips);
    waiting_for_human_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    /// Clear so QML `humanDecisionActive` is false after fold/call/raise; otherwise embedded HUD
    /// keeps hiding the last-hand status banner until the next `clear_for_new_hand`.
    decision_seconds_left_ = 0;
    game_.sync_ui();
    emit humanDecisionFinished();
}

void HumanDecisionController::submitCheckOrBet(bool check, int betChips)
{
    finish_human_check(check, betChips);
}

void HumanDecisionController::submitFoldFromCheck()
{
    if (!waiting_for_human_check_)
        return;
    waiting_for_human_check_ = false;
    human_opened_bet_from_check_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    game_.set_seat_street_action(game::kHumanSeat, QStringLiteral("Fold"));
    game_.in_hand_[static_cast<size_t>(game::kHumanSeat)] = false;
    emit humanCheckFinished();
}

bool HumanDecisionController::wait_for_human_check_or_bet(Street st)
{
    (void)st;
    if (!game_.m_root)
        return false;

    if (game_.table[static_cast<size_t>(game::kHumanSeat)].stack <= 0)
        return false;

    waiting_for_human_check_ = true;
    human_opened_bet_from_check_ = false;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

    arm_decision_timers([this]() {
        if (waiting_for_human_check_)
            submitFoldFromCheck();
    });

    game_.acting_seat_ = game::kHumanSeat;
    game_.sync_ui();

    if (game_.human_sitting_out_)
    {
        submitFoldFromCheck();
        game_.acting_seat_ = -1;
        decision_seconds_left_ = 0;
        game_.sync_ui();
        return false;
    }

    human_decision_tick_.start();
    human_decision_deadline_.start();
    game_.sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &HumanDecisionController::humanCheckFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    game_.acting_seat_ = -1;
    decision_seconds_left_ = 0;
    waiting_for_human_check_ = false;
    game_.sync_ui();

    return human_opened_bet_from_check_;
}

void HumanDecisionController::finish_human_check(bool check, int bet_chips)
{
    if (!waiting_for_human_check_)
        return;
    waiting_for_human_check_ = false;
    human_opened_bet_from_check_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    if (!check)
    {
        const size_t hi = static_cast<size_t>(game::kHumanSeat);
        const int stack = game_.table[hi].stack;
        const int sb = game_.getStreetBet();
        const int min_open = (stack >= sb) ? sb : stack;
        const int chips = std::clamp(bet_chips, min_open, stack);
        if (chips < min_open)
        {
            emit humanCheckFinished();
            return;
        }
        const int taken = game_.table[hi].take_from_stack(chips);
        game_.add_chips_to_pot(game::kHumanSeat, taken);
        game_.street_contrib_[hi] += taken;
        game_.last_raise_increment_ = chips;
        human_opened_bet_from_check_ = true;
        game_.note_river_aggressor(game_.street, game::kHumanSeat);
        {
            const QString lbl = (game_.table[hi].stack <= 0 && taken > 0)
                                      ? QStringLiteral("All-in $%1").arg(taken)
                                      : QStringLiteral("Raise $%1").arg(taken);
            game_.set_seat_street_action(game::kHumanSeat, lbl);
        }
        emit game_.pot_changed();
    }
    else
    {
        game_.set_seat_street_action(game::kHumanSeat, QStringLiteral("Check"));
    }
    emit humanCheckFinished();
}

bool HumanDecisionController::wait_for_human_bb_preflop()
{
    if (!game_.m_root)
        return false;

    waiting_for_human_bb_preflop_ = true;
    human_bb_preflop_raised_ = false;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

    arm_decision_timers([this]() { finish_human_bb_preflop(false); });

    game_.acting_seat_ = game::kHumanSeat;
    game_.sync_ui();

    if (game_.human_sitting_out_)
    {
        finish_human_bb_preflop(false);
        game_.acting_seat_ = -1;
        decision_seconds_left_ = 0;
        game_.sync_ui();
        return false;
    }

    human_decision_tick_.start();
    human_decision_deadline_.start();
    game_.sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &HumanDecisionController::humanBbPreflopFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    game_.acting_seat_ = -1;
    decision_seconds_left_ = 0;
    waiting_for_human_bb_preflop_ = false;
    game_.sync_ui();

    return human_bb_preflop_raised_;
}

void HumanDecisionController::finish_human_bb_preflop(bool raise)
{
    if (!waiting_for_human_bb_preflop_)
        return;
    if (raise)
        return;
    waiting_for_human_bb_preflop_ = false;
    human_bb_preflop_raised_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    game_.set_seat_street_action(game::kHumanSeat, QStringLiteral("Check"));
    emit humanBbPreflopFinished();
}

void HumanDecisionController::submitBbPreflopRaise(int chips_to_add)
{
    if (!waiting_for_human_bb_preflop_)
        return;
    waiting_for_human_bb_preflop_ = false;
    human_bb_preflop_raised_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    const int inc = game::min_raise_increment_chips(game_.big_blind, game_.last_raise_increment_);
    const size_t bi = static_cast<size_t>(game::kHumanSeat);
    if (inc <= 0 || game_.max_street_contrib() != game_.preflop_blind_level_
        || game_.table[bi].stack <= 0)
    {
        game_.set_seat_street_action(game::kHumanSeat, QStringLiteral("Check"));
        emit humanBbPreflopFinished();
        return;
    }
    const int c = std::clamp(chips_to_add, inc, game_.table[bi].stack);
    if (c < inc)
    {
        game_.set_seat_street_action(game::kHumanSeat, QStringLiteral("Check"));
        emit humanBbPreflopFinished();
        return;
    }
    const int taken = game_.table[bi].take_from_stack(c);
    game_.add_chips_to_pot(game::kHumanSeat, taken);
    game_.street_contrib_[bi] += taken;
    game_.last_raise_increment_ = taken;
    human_bb_preflop_raised_ = true;
    game_.bb_preflop_option_open_ = false;
    {
        const QString lbl =
            (game_.table[bi].stack <= 0 && taken > 0)
                ? QStringLiteral("All-in $%1").arg(taken)
                : QStringLiteral("Raise to $%1").arg(static_cast<int>(game_.street_contrib_[bi]));
        game_.set_seat_street_action(game::kHumanSeat, lbl);
    }
    emit game_.pot_changed();
    emit humanBbPreflopFinished();
}
