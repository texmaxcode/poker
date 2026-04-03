// Table engine: betting rounds, bots, blinds, persistence, human decision timers.
// QML-facing `sync_ui` / `flush_ui` live in game_ui_sync.cpp.

#include "game.hpp"

#include "hand_eval.hpp"
#include "holdem_side_pot.hpp"

#include "cards.hpp"

#include <algorithm>
#include <array>
#include <cassert>
#include <cmath>
#include <random>

#include <QCoreApplication>
#include <QDateTime>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace {

constexpr int kDecisionSeconds = 20;
constexpr int kMoreTimeExtraSeconds = 20;
constexpr int kMaxDecisionSecondsCap = 120;

BotParams clamp_bot_params(BotParams p)
{
    auto c = [](double v, double lo, double hi) { return std::max(lo, std::min(hi, v)); };
    p.preflop_exponent = c(p.preflop_exponent, 0.05, 5.0);
    p.postflop_exponent = c(p.postflop_exponent, 0.05, 5.0);
    p.facing_raise_bonus = c(p.facing_raise_bonus, 0.0, 0.5);
    p.facing_raise_tight_mul = c(p.facing_raise_tight_mul, 0.1, 1.0);
    p.open_bet_bonus = c(p.open_bet_bonus, 0.0, 0.5);
    p.open_bet_tight_mul = c(p.open_bet_tight_mul, 0.1, 1.0);
    p.bb_checkraise_bonus = c(p.bb_checkraise_bonus, 0.0, 0.5);
    p.bb_checkraise_tight_mul = c(p.bb_checkraise_tight_mul, 0.1, 1.0);
    return p;
}

bool rng_passes_layer_gate(double layer_w, double play_w, std::mt19937 &rng)
{
    if (play_w <= 1e-15)
        return false;
    const double p = std::min(1.0, std::max(0.0, layer_w / play_w));
    std::uniform_real_distribution<double> u(0.0, 1.0);
    return u(rng) < p;
}

double play_weight_cards(const SeatBot &sb, const card &a, const card &b)
{
    const double c = sb.range_call.weight(a, b);
    const double r = sb.range_raise.weight(a, b);
    const double bet = sb.range_bet.weight(a, b);
    return std::max({c, r, bet});
}

const RangeMatrix *layer_matrix_c(const SeatBot &sb, int layer)
{
    switch (layer)
    {
    case 1:
        return &sb.range_raise;
    case 2:
        return &sb.range_bet;
    default:
        return &sb.range_call;
    }
}

RangeMatrix *layer_matrix(SeatBot &sb, int layer)
{
    return const_cast<RangeMatrix *>(layer_matrix_c(sb, layer));
}

/// Matches `BotNames.qml` display names for status strings (no seat numbers in UI).
QString seat_display_name(int seat)
{
    switch (seat)
    {
    case 0:
        return QStringLiteral("You");
    case 1:
        return QStringLiteral("Peter");
    case 2:
        return QStringLiteral("James");
    case 3:
        return QStringLiteral("John");
    case 4:
        return QStringLiteral("Andrew");
    case 5:
        return QStringLiteral("Philip");
    default:
        return QStringLiteral("Player %1").arg(seat + 1);
    }
}

} // namespace

void game::arm_decision_timers(std::function<void()> on_deadline)
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
            sync_ui();
        }
    });
    QObject::connect(&human_decision_deadline_, &QTimer::timeout, this,
                     [fn = std::move(on_deadline)]() mutable { fn(); });
}

int game::min_raise_increment_chips(int big_blind, int last_raise_increment)
{
    return std::max(big_blind, last_raise_increment);
}

bool game::is_game_in_progress() const
{
    return in_progress;
}

void game::join_table(player p)
{
    if (table.size() >= static_cast<size_t>(kMaxPlayers))
        return;
    const bool more_than_ten_blinds = (p.stack >= 10 * big_blind);
    const bool less_than_hundred_blinds = (p.stack <= 100 * big_blind);
    const bool has_enough_money = more_than_ten_blinds && less_than_hundred_blinds;
    if (has_enough_money)
        table.push_back(p);
}

int game::players_count() const
{
    return static_cast<int>(table.size());
}

void game::add_chips_to_pot(int seat, int chips)
{
    if (chips <= 0 || seat < 0 || seat >= kMaxPlayers)
        return;
    pot += chips;
    hand_contrib_[static_cast<size_t>(seat)] += chips;
}

void game::collect_blinds()
{
    const int n = players_count();
    if (n < 2 || count_active() < 2)
        return;
    int sb = 0;
    int bb = 0;
    compute_blind_seats(sb, bb);
    if (sb < 0 || bb < 0)
        return;
    const int sba = table[static_cast<size_t>(sb)].pay(small_blind);
    const int bba = table[static_cast<size_t>(bb)].pay(big_blind);
    add_chips_to_pot(sb, sba);
    add_chips_to_pot(bb, bba);
    emit pot_changed();
}

void game::take_bets_for_testing()
{
    const int n = players_count();
    if (n < 2)
        return;
    for (int i = 0; i < n; ++i)
    {
        const int taken = table[static_cast<size_t>(i)].take_from_stack(street_bet_);
        add_chips_to_pot(i, taken);
    }
    emit pot_changed();
}

void game::deal_hold_cards()
{
    const int n = players_count();
    if (n < 2 || count_active() < 2)
        return;
    int sb = 0;
    int bb = 0;
    compute_blind_seats(sb, bb);
    (void)bb;
    if (sb < 0)
        return;

    std::vector<int> deal_order;
    deal_order.reserve(static_cast<size_t>(n));
    int s = sb;
    for (int i = 0; i < n; ++i)
    {
        if (in_hand_[static_cast<size_t>(s)])
            deal_order.push_back(s);
        s = (s + 1) % n;
    }
    if (deal_order.size() < 2)
        return;

    for (int round = 0; round < 2; ++round)
    {
        for (int seat : deal_order)
        {
            const card c = deck.get_card();
            if (round == 0)
                table[static_cast<size_t>(seat)].first_card = c;
            else
                table[static_cast<size_t>(seat)].second_card = c;
        }
    }
    cards_dealt_ = true;
}

void game::deal_flop()
{
    (void)deck.get_card();
    for (auto i = 0; i < 3; ++i)
        flop.push_back(deck.get_card());
}

void game::deal_turn()
{
    (void)deck.get_card();
    turn = deck.get_card();
}

void game::deal_river()
{
    (void)deck.get_card();
    river = deck.get_card();
}

std::vector<card> game::get_hand_vector(int idx) const
{
    assert(flop.size() >= 3);
    std::vector<card> v;
    v.reserve(7);
    v.push_back(table[static_cast<size_t>(idx)].first_card);
    v.push_back(table[static_cast<size_t>(idx)].second_card);
    v.push_back(flop[0]);
    v.push_back(flop[1]);
    v.push_back(flop[2]);
    v.push_back(turn);
    v.push_back(river);
    std::sort(v.begin(), v.end());
    return v;
}

std::vector<card> game::cards_for_strength(int seat, Street st) const
{
    std::vector<card> v;
    v.push_back(table[static_cast<size_t>(seat)].first_card);
    v.push_back(table[static_cast<size_t>(seat)].second_card);
    for (const auto &c : flop)
        v.push_back(c);
    if (st >= Street::TURN)
        v.push_back(turn);
    if (st >= Street::RIVER)
        v.push_back(river);
    return v;
}

QString game::human_hand_line_for_ui() const
{
    if (human_sitting_out_)
        return {};
    if (!in_hand_[static_cast<size_t>(kHumanSeat)])
        return {};
    if (!cards_dealt_)
        return {};
    const auto v = cards_for_strength(kHumanSeat, street);
    if (v.size() < 2)
        return {};
    return QString::fromStdString(describe_holdem_hand(v));
}

QString game::board_line_for_ui() const
{
    if (flop.size() < 3)
        return {};
    QString out = QStringLiteral("Board: ");
    out += card_to_display_string(flop[0]) + QLatin1Char(' ') + card_to_display_string(flop[1]) + QLatin1Char(' ')
        + card_to_display_string(flop[2]);
    if (street >= Street::TURN)
        out += QLatin1Char(' ') + card_to_display_string(turn);
    if (street >= Street::RIVER)
        out += QLatin1Char(' ') + card_to_display_string(river);
    return out;
}

QString game::hole_cards_display(int seat) const
{
    if (seat < 0 || seat >= players_count())
        return {};
    return card_to_display_string(table[static_cast<size_t>(seat)].first_card) + QLatin1Char(' ')
        + card_to_display_string(table[static_cast<size_t>(seat)].second_card);
}

QString game::winning_hand_label(int seat) const
{
    const auto v = cards_for_strength(seat, street);
    if (v.size() < 2)
        return {};
    return QString::fromStdString(describe_holdem_hand(v));
}

QString game::hand_result_status_line(int seat) const
{
    QString line = seat_display_name(seat);
    const QString handName = winning_hand_label(seat);
    if (!handName.isEmpty())
        line += QStringLiteral(" — ") + handName;
    line += QStringLiteral(" — ") + hole_cards_display(seat);
    const QString brd = board_compact_for_result();
    if (!brd.isEmpty())
        line += QStringLiteral(" · ") + brd;
    return line;
}

// Preflop: first actor is UTG — clockwise after the big blind (heads-up: button / small blind first).
// Flop+: first actor is clockwise from the button (small blind if still in; heads-up: big blind first).
std::vector<int> game::action_order(Street st) const
{
    const int n = players_count();
    std::vector<int> order;
    if (n < 2)
        return order;

    int start = -1;
    if (st == Street::PRE_FLOP)
    {
        if (bb_seat_ < 0)
            return order;
        start = first_in_hand_after(bb_seat_);
    }
    else
    {
        start = first_in_hand_after(button);
    }

    if (start < 0)
        return order;

    order.reserve(static_cast<size_t>(n));
    for (int k = 0; k < n; ++k)
    {
        const int seat = (start + k) % n;
        if (in_hand_[static_cast<size_t>(seat)])
            order.push_back(seat);
    }
    return order;
}

int game::count_active() const
{
    int c = 0;
    for (int i = 0; i < players_count(); ++i)
    {
        if (in_hand_[static_cast<size_t>(i)])
            ++c;
    }
    return c;
}

int game::max_street_contrib() const
{
    int m = 0;
    const int n = players_count();
    for (int i = 0; i < n; ++i)
    {
        if (in_hand_[static_cast<size_t>(i)])
            m = std::max(m, street_contrib_[static_cast<size_t>(i)]);
    }
    return m;
}

void game::init_preflop_street_contrib()
{
    clear_street_action_labels();
    street_contrib_.fill(0);
    compute_blind_seats(sb_seat_, bb_seat_);
    if (sb_seat_ < 0 || bb_seat_ < 0)
        return;
    street_contrib_[static_cast<size_t>(sb_seat_)] = small_blind;
    street_contrib_[static_cast<size_t>(bb_seat_)] = big_blind;
    set_seat_street_action(sb_seat_, QStringLiteral("SB $%1").arg(small_blind));
    set_seat_street_action(bb_seat_, QStringLiteral("BB $%1").arg(big_blind));
    last_raise_increment_ = big_blind;
    bb_preflop_option_open_ = true;
}

void game::reset_postflop_street_contrib()
{
    clear_street_action_labels();
    const int n = players_count();
    for (int i = 0; i < n; ++i)
    {
        if (in_hand_[static_cast<size_t>(i)])
            street_contrib_[static_cast<size_t>(i)] = 0;
    }
    last_raise_increment_ = big_blind;
}

void game::wait_for_human_need(int need_chips, Street st, int raise_increment_chips)
{
    (void)st;

    if (!m_root)
        return;
    if (need_chips <= 0)
        return;

    const size_t hi = static_cast<size_t>(kHumanSeat);
    if (table[hi].stack <= 0)
    {
        /// Defensive: should be handled in `handle_forced_response` — resolve as call for 0 chips.
        human_facing_action_ = 1;
        human_facing_raise_chips_ = 0;
        pending_human_need_ = 0;
        pending_human_raise_inc_ = raise_increment_chips;
        sync_ui();
        return;
    }

    /// Effective call (short stacks all-in for less than full `need_chips`).
    pending_human_need_ =
        std::min(need_chips, std::max(0, table[static_cast<size_t>(kHumanSeat)].stack));
    pending_human_raise_inc_ = raise_increment_chips;
    waiting_for_human_ = true;
    human_facing_action_ = -1;
    human_facing_raise_chips_ = 0;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

    arm_decision_timers([this]() { submitFacingAction(0, 0); });
    sync_ui();

    if (human_sitting_out_)
    {
        submitFacingAction(0, 0);
        return;
    }

    human_decision_tick_.start();
    human_decision_deadline_.start();
    sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &game::humanDecisionFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();
}

void game::submitFacingAction(int action, int raiseChips)
{
    if (!waiting_for_human_)
        return;
    human_facing_action_ = action;
    human_facing_raise_chips_ = std::max(0, raiseChips);
    waiting_for_human_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    emit humanDecisionFinished();
}

void game::submitCheckOrBet(bool check, int betChips)
{
    finish_human_check(check, betChips);
}

void game::submitFoldFromCheck()
{
    if (!waiting_for_human_check_)
        return;
    waiting_for_human_check_ = false;
    human_opened_bet_from_check_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    set_seat_street_action(kHumanSeat, QStringLiteral("Fold"));
    push_human_action_status(QStringLiteral("Fold"));
    in_hand_[static_cast<size_t>(kHumanSeat)] = false;
    emit humanCheckFinished();
}

bool game::wait_for_human_check_or_bet(Street st)
{
    (void)st;
    if (!m_root)
        return false;

    if (table[static_cast<size_t>(kHumanSeat)].stack <= 0)
        return false;

    waiting_for_human_check_ = true;
    human_opened_bet_from_check_ = false;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

    arm_decision_timers([this]() {
        if (waiting_for_human_check_)
            submitFoldFromCheck();
    });

    acting_seat_ = kHumanSeat;
    sync_ui();

    if (human_sitting_out_)
    {
        submitFoldFromCheck();
        acting_seat_ = -1;
        decision_seconds_left_ = 0;
        sync_ui();
        return false;
    }

    human_decision_tick_.start();
    human_decision_deadline_.start();
    sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &game::humanCheckFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    acting_seat_ = -1;
    decision_seconds_left_ = 0;
    waiting_for_human_check_ = false;
    sync_ui();

    return human_opened_bet_from_check_;
}

void game::finish_human_check(bool check, int bet_chips)
{
    if (!waiting_for_human_check_)
        return;
    waiting_for_human_check_ = false;
    human_opened_bet_from_check_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    if (!check)
    {
        const size_t hi = static_cast<size_t>(kHumanSeat);
        /// NL: allow any open size from 1 chip up to stack (bots still use `street_bet_` as default open).
        const int min_open = 1;
        const int chips = std::clamp(bet_chips, min_open, table[hi].stack);
        if (chips < min_open)
        {
            emit humanCheckFinished();
            return;
        }
        const int taken = table[hi].take_from_stack(chips);
        add_chips_to_pot(kHumanSeat, taken);
        street_contrib_[hi] += taken;
        last_raise_increment_ = chips;
        human_opened_bet_from_check_ = true;
        note_river_aggressor(street, kHumanSeat);
        {
            const QString lbl = (table[hi].stack <= 0 && taken > 0)
                                      ? QStringLiteral("All-in $%1").arg(taken)
                                      : QStringLiteral("Raise $%1").arg(taken);
            set_seat_street_action(kHumanSeat, lbl);
            push_human_action_status(lbl);
        }
        emit pot_changed();
    }
    else
    {
        set_seat_street_action(kHumanSeat, QStringLiteral("Check"));
        push_human_action_status(QStringLiteral("Check"));
    }
    emit humanCheckFinished();
}

bool game::wait_for_human_bb_preflop()
{
    if (!m_root)
        return false;

    waiting_for_human_bb_preflop_ = true;
    human_bb_preflop_raised_ = false;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

    arm_decision_timers([this]() { finish_human_bb_preflop(false); });

    acting_seat_ = kHumanSeat;
    sync_ui();

    if (human_sitting_out_)
    {
        finish_human_bb_preflop(false);
        acting_seat_ = -1;
        decision_seconds_left_ = 0;
        sync_ui();
        return false;
    }

    human_decision_tick_.start();
    human_decision_deadline_.start();
    sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &game::humanBbPreflopFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    acting_seat_ = -1;
    decision_seconds_left_ = 0;
    waiting_for_human_bb_preflop_ = false;
    sync_ui();

    return human_bb_preflop_raised_;
}

void game::finish_human_bb_preflop(bool raise)
{
    if (!waiting_for_human_bb_preflop_)
        return;
    if (raise)
        return;
    waiting_for_human_bb_preflop_ = false;
    human_bb_preflop_raised_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    set_seat_street_action(kHumanSeat, QStringLiteral("Check"));
    push_human_action_status(QStringLiteral("Check"));
    emit humanBbPreflopFinished();
}

void game::submitBbPreflopRaise(int chips_to_add)
{
    if (!waiting_for_human_bb_preflop_)
        return;
    waiting_for_human_bb_preflop_ = false;
    human_bb_preflop_raised_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    const int inc = min_raise_increment_chips(big_blind, last_raise_increment_);
    const size_t bi = static_cast<size_t>(kHumanSeat);
    if (inc <= 0 || max_street_contrib() != big_blind || table[bi].stack <= 0)
    {
        set_seat_street_action(kHumanSeat, QStringLiteral("Check"));
        push_human_action_status(QStringLiteral("Check"));
        emit humanBbPreflopFinished();
        return;
    }
    const int c = std::clamp(chips_to_add, inc, table[bi].stack);
    if (c < inc)
    {
        set_seat_street_action(kHumanSeat, QStringLiteral("Check"));
        push_human_action_status(QStringLiteral("Check"));
        emit humanBbPreflopFinished();
        return;
    }
    const int taken = table[bi].take_from_stack(c);
    add_chips_to_pot(kHumanSeat, taken);
    street_contrib_[bi] += taken;
    last_raise_increment_ = taken;
    human_bb_preflop_raised_ = true;
    bb_preflop_option_open_ = false;
    {
        const QString lbl =
            (table[bi].stack <= 0 && taken > 0)
                ? QStringLiteral("All-in $%1").arg(taken)
                : QStringLiteral("Raise to $%1").arg(static_cast<int>(street_contrib_[bi]));
        set_seat_street_action(kHumanSeat, lbl);
        push_human_action_status(lbl);
    }
    emit pot_changed();
    emit humanBbPreflopFinished();
}

void game::setInteractiveHuman(bool enabled)
{
    interactive_human_ = enabled;
}

void game::setHumanSitOut(bool enabled)
{
    human_sitting_out_ = enabled;
    if (m_root)
        m_root->setProperty("humanSittingOut", human_sitting_out_);
    if (enabled)
    {
        if (waiting_for_human_)
            submitFacingAction(0, 0);
        else if (waiting_for_human_check_)
            submitFoldFromCheck();
        else if (waiting_for_human_bb_preflop_)
            finish_human_bb_preflop(false);
    }
    sync_ui();
}

int game::first_in_hand_after(int prev_seat) const
{
    const int n = players_count();
    if (n < 1)
        return -1;
    for (int k = 1; k <= n; ++k)
    {
        const int s = (prev_seat + k) % n;
        if (in_hand_[static_cast<size_t>(s)])
            return s;
    }
    return -1;
}

bool game::seat_eligible_for_positions(int seat) const
{
    if (seat < 0 || seat >= players_count())
        return false;
    if (table[static_cast<size_t>(seat)].stack <= 0)
        return false;
    if (seat == kHumanSeat)
        return !human_sitting_out_;
    return seat_participating_[static_cast<size_t>(seat)];
}

int game::next_seat_in_position_pool(int from) const
{
    const int n = players_count();
    if (n < 1)
        return -1;
    for (int k = 1; k <= n; ++k)
    {
        const int s = (from + k) % n;
        if (seat_eligible_for_positions(s))
            return s;
    }
    return -1;
}

void game::ensure_button_on_eligible_seat()
{
    if (players_count() < 1)
        return;
    if (seat_eligible_for_positions(button))
        return;
    const int next = next_seat_in_position_pool(button);
    if (next >= 0)
        button = next;
    else
    {
        const int n = players_count();
        for (int s = 0; s < n; ++s)
        {
            if (seat_eligible_for_positions(s))
            {
                button = s;
                return;
            }
        }
    }
}

void game::compute_blind_seats(int &sb, int &bb) const
{
    const int n = players_count();
    if (n < 2)
    {
        sb = bb = -1;
        return;
    }
    // Use players actually in this hand (not empty seats / sit-outs), not raw table size.
    const int active = count_active();
    if (active < 2)
    {
        sb = bb = -1;
        return;
    }
    // 3+ players: SB clockwise from button, BB clockwise from SB (Bicycle / standard ring).
    // Heads-up: the button posts the small blind; the other player posts the big blind
    // (WSOP / Robert's Rules — differs from "next active after button" which would swap SB/BB).
    if (active == 2)
    {
        sb = button;
        bb = first_in_hand_after(button);
        if (bb < 0)
            sb = bb = -1;
        return;
    }
    sb = first_in_hand_after(button);
    bb = first_in_hand_after(sb);
    if (sb < 0 || bb < 0)
        sb = bb = -1;
}

void game::setAutoHandLoop(bool enabled)
{
    auto_hand_loop_ = enabled;
}

// Does not reset the 1 Hz tick; only reschedules the decision deadline (see `arm_decision_timers`).
void game::requestMoreTime()
{
    if ((!waiting_for_human_ && !waiting_for_human_check_ && !waiting_for_human_bb_preflop_) || !m_root ||
        !human_more_time_available_)
        return;
    human_more_time_available_ = false;
    decision_seconds_left_ =
        std::min(decision_seconds_left_ + kMoreTimeExtraSeconds, kMaxDecisionSecondsCap);
    human_decision_deadline_.stop();
    human_decision_deadline_.setSingleShot(true);
    human_decision_deadline_.setInterval(decision_seconds_left_ * 1000);
    human_decision_deadline_.start();
    sync_ui();
}

void game::schedule_next_hand_if_idle()
{
    if (!auto_hand_loop_ || !interactive_human_)
        return;
    QTimer::singleShot(1800, this, [this]() {
        if (!m_root)
            return;
        beginNewHand();
    });
}

bool game::apply_buy_back_in_internal(int seat)
{
    if (seat < 0 || seat >= players_count())
        return false;
    const size_t si = static_cast<size_t>(seat);
    if (in_progress && in_hand_[si])
        return false;
    if (table[si].stack > 0)
        return false;
    const int cost = seat_buy_in_[si];
    if (seat_wallet_[si] < cost)
        return false;
    table[si].stack += cost;
    seat_wallet_[si] -= cost;
    return true;
}

void game::try_auto_rebuys_for_busted_bots()
{
    const int n = players_count();
    for (int s = 1; s < n; ++s)
    {
        if (!seat_participating_[static_cast<size_t>(s)])
            continue;
        const size_t si = static_cast<size_t>(s);
        if (table[si].stack > 0)
            continue;
        // Bots get an off-table reserve when busted so they can keep playing (humans start wallet at 0 on apply).
        if (seat_wallet_[si] < seat_buy_in_[si])
            seat_wallet_[si] = seat_buy_in_[si];
        if (seat_wallet_[si] >= seat_buy_in_[si])
            apply_buy_back_in_internal(s);
    }
}

void game::bot_action_pause()
{
    if (!bot_action_delay_enabled_)
        return;
    const int ms = bot_slow_actions_ ? 2600 : 550;
    QElapsedTimer t;
    t.start();
    while (t.elapsed() < ms)
        QCoreApplication::processEvents(QEventLoop::AllEvents, 16);
}

void game::bot_record_postflop_check(int seat)
{
    acting_seat_ = seat;
    flush_ui();
    bot_action_pause();
    set_seat_street_action(seat, QStringLiteral("Check"));
    acting_seat_ = -1;
    sync_ui();
}

bool game::handle_forced_response(int seat, Street st, int current_max)
{
    const size_t si = static_cast<size_t>(seat);
    int need = current_max - street_contrib_[si];
    if (need <= 0)
        return true;

    const int inc = min_raise_increment_chips(big_blind, last_raise_increment_);

    if (seat == kHumanSeat)
    {
        if (!interactive_human_ || !m_root)
        {
            const int stack_before = table[si].stack;
            const int taken = table[si].take_from_stack(need);
            add_chips_to_pot(seat, taken);
            street_contrib_[si] += taken;
            if (taken >= stack_before)
                set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken));
            else
                set_seat_street_action(seat, QStringLiteral("Call $%1").arg(taken));
            emit pot_changed();
            return true;
        }

        /// No chips behind — already all-in for this street; do not open the human action UI.
        if (table[si].stack <= 0)
            return true;

        acting_seat_ = seat;
        decision_seconds_left_ = kDecisionSeconds;
        flush_ui();

        wait_for_human_need(need, st, inc);
        acting_seat_ = -1;
        decision_seconds_left_ = 0;
        sync_ui();

        if (human_facing_action_ == 0)
        {
            set_seat_street_action(seat, QStringLiteral("Fold"));
            push_human_action_status(QStringLiteral("Fold"));
            in_hand_[si] = false;
            return true;
        }

        if (human_facing_action_ == 2)
        {
            int chips = human_facing_raise_chips_;
            if (chips <= 0)
                chips = need + inc;
            chips = std::min(chips, table[si].stack);
            if (chips <= 0)
            {
                set_seat_street_action(seat, QStringLiteral("Fold"));
                push_human_action_status(QStringLiteral("Fold"));
                in_hand_[si] = false;
                return true;
            }
            if (chips < need)
            {
                const int taken_short = table[si].take_from_stack(chips);
                add_chips_to_pot(seat, taken_short);
                street_contrib_[si] += taken_short;
                {
                    const QString lbl = QStringLiteral("All-in $%1").arg(taken_short);
                    set_seat_street_action(seat, lbl);
                    push_human_action_status(lbl);
                }
                emit pot_changed();
                return true;
            }
            const int stack_before_raise = table[si].stack;
            const int taken_raise = table[si].take_from_stack(chips);
            add_chips_to_pot(seat, taken_raise);
            street_contrib_[si] += taken_raise;
            const int new_contrib = static_cast<int>(street_contrib_[si]);
            if (new_contrib > current_max)
            {
                last_raise_increment_ = new_contrib - current_max;
                if (new_contrib > big_blind)
                    bb_preflop_option_open_ = false;
                note_river_aggressor(st, seat);
                if (taken_raise >= stack_before_raise)
                {
                    const QString lbl = QStringLiteral("All-in $%1").arg(taken_raise);
                    set_seat_street_action(seat, lbl);
                    push_human_action_status(lbl);
                }
                else
                {
                    const QString lbl = QStringLiteral("Raise to $%1").arg(new_contrib);
                    set_seat_street_action(seat, lbl);
                    push_human_action_status(lbl);
                }
            }
            else if (taken_raise >= stack_before_raise)
            {
                const QString lbl = QStringLiteral("All-in $%1").arg(taken_raise);
                set_seat_street_action(seat, lbl);
                push_human_action_status(lbl);
            }
            else
            {
                const QString lbl = QStringLiteral("Call $%1").arg(taken_raise);
                set_seat_street_action(seat, lbl);
                push_human_action_status(lbl);
            }
            emit pot_changed();
            return true;
        }

        const int stack_before_call = table[si].stack;
        const int taken_call = table[si].take_from_stack(need);
        add_chips_to_pot(seat, taken_call);
        street_contrib_[si] += taken_call;
        if (taken_call >= stack_before_call)
        {
            const QString lbl = QStringLiteral("All-in $%1").arg(taken_call);
            set_seat_street_action(seat, lbl);
            push_human_action_status(lbl);
        }
        else
        {
            const QString lbl = QStringLiteral("Call $%1").arg(taken_call);
            set_seat_street_action(seat, lbl);
            push_human_action_status(lbl);
        }
        emit pot_changed();
        return true;
    }

    acting_seat_ = seat;
    decision_seconds_left_ = 0;
    flush_ui();
    bot_action_pause();

    bool cont = false;
    double metric = 0.0;
    double wr_preflop = 0.0;
    double play_preflop = 0.0;
    if (st == Street::PRE_FLOP)
    {
        const card &c1 = table[si].first_card;
        const card &c2 = table[si].second_card;
        wr_preflop = seat_cfg_[si].range_raise.weight(c1, c2);
        play_preflop = play_weight_cards(seat_cfg_[si], c1, c2);
        metric = play_preflop;
        if (seat_cfg_[si].strategy == BotStrategy::AlwaysCall)
            cont = true;
        else
            cont = bot_preflop_continue_p(seat_cfg_[si].params, metric, rng_);
    }
    else
    {
        const auto cards = cards_for_strength(seat, st);
        metric = hand_strength_01_cards(cards);
        if (seat_cfg_[si].strategy == BotStrategy::AlwaysCall)
            cont = true;
        else
            cont = bot_postflop_continue_p(seat_cfg_[si].params, metric, rng_);
    }

    if (!cont)
    {
        set_seat_street_action(seat, QStringLiteral("Fold"));
        in_hand_[si] = false;
        acting_seat_ = -1;
        sync_ui();
        return true;
    }

    const bool try_raise = seat_cfg_[si].strategy == BotStrategy::AlwaysCall
                               ? false
                               : bot_wants_raise_after_continue_p(seat_cfg_[si].params, metric, rng_);
    const int new_max = current_max + inc;
    const int chips_for_raise = new_max - static_cast<int>(street_contrib_[si]);

    if (try_raise && table[si].stack >= chips_for_raise && chips_for_raise > need)
    {
        if (st != Street::PRE_FLOP || rng_passes_layer_gate(wr_preflop, play_preflop, rng_))
        {
            const int taken_r = table[si].take_from_stack(chips_for_raise);
            add_chips_to_pot(seat, taken_r);
            street_contrib_[si] += taken_r;
            last_raise_increment_ = new_max - current_max;
            if (new_max > big_blind)
                bb_preflop_option_open_ = false;
            note_river_aggressor(st, seat);
            if (table[si].stack <= 0 && taken_r > 0)
                set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken_r));
            else
                set_seat_street_action(seat,
                                       QStringLiteral("Raise to $%1").arg(static_cast<int>(street_contrib_[si])));
            emit pot_changed();
            acting_seat_ = -1;
            sync_ui();
            return true;
        }
    }

    const int stack_before_bot_call = table[si].stack;
    const int taken_bot = table[si].take_from_stack(need);
    add_chips_to_pot(seat, taken_bot);
    street_contrib_[si] += taken_bot;
    if (taken_bot >= stack_before_bot_call)
        set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken_bot));
    else
        set_seat_street_action(seat, QStringLiteral("Call $%1").arg(taken_bot));
    emit pot_changed();
    acting_seat_ = -1;
    sync_ui();
    return true;
}

bool game::handle_postflop_check_or_bet(Street st)
{
    const std::vector<int> order = action_order(st);
    for (int seat : order)
    {
        if (!in_hand_[static_cast<size_t>(seat)])
            continue;
        /// No check/bet turn when already all-in for this hand — action skips to players with chips behind.
        if (table[static_cast<size_t>(seat)].stack <= 0)
            continue;
        if (seat == kHumanSeat)
        {
            if (!interactive_human_ || !m_root)
                continue;
            if (wait_for_human_check_or_bet(st))
                return true;
            continue;
        }

        const auto cards = cards_for_strength(seat, st);
        const double hs = hand_strength_01_cards(cards);
        const size_t sei = static_cast<size_t>(seat);
        if (seat_cfg_[sei].strategy == BotStrategy::AlwaysCall)
        {
            bot_record_postflop_check(seat);
            continue;
        }
        if (!bot_wants_open_bet_postflop_p(seat_cfg_[sei].params, hs, rng_))
        {
            bot_record_postflop_check(seat);
            continue;
        }
        {
            const card &h1 = table[sei].first_card;
            const card &h2 = table[sei].second_card;
            const double wc = seat_cfg_[sei].range_call.weight(h1, h2);
            const double wr = seat_cfg_[sei].range_raise.weight(h1, h2);
            const double wb = seat_cfg_[sei].range_bet.weight(h1, h2);
            const double play = std::max({wc, wr, wb});
            if (!rng_passes_layer_gate(wb, play, rng_))
            {
                bot_record_postflop_check(seat);
                continue;
            }
        }
        if (table[static_cast<size_t>(seat)].stack < street_bet_)
        {
            bot_record_postflop_check(seat);
            continue;
        }
        acting_seat_ = seat;
        flush_ui();
        bot_action_pause();
        acting_seat_ = -1;
        const int taken_open = table[static_cast<size_t>(seat)].take_from_stack(street_bet_);
        add_chips_to_pot(seat, taken_open);
        street_contrib_[static_cast<size_t>(seat)] += taken_open;
        last_raise_increment_ = street_bet_;
        note_river_aggressor(st, seat);
        if (table[static_cast<size_t>(seat)].stack <= 0 && taken_open > 0)
            set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken_open));
        else
            set_seat_street_action(seat, QStringLiteral("Raise $%1").arg(street_bet_));
        emit pot_changed();
        return true;
    }
    return false;
}

bool game::handle_bb_preflop_option()
{
    const int n = players_count();
    const int bb = bb_seat_;
    bb_preflop_option_open_ = false;

    if (bb < 0 || bb >= n || !in_hand_[static_cast<size_t>(bb)])
        return false;

    if (bb == kHumanSeat)
    {
        if (!interactive_human_ || !m_root)
            return false;
        if (table[static_cast<size_t>(kHumanSeat)].stack <= 0)
            return false;
        return wait_for_human_bb_preflop();
    }

    const size_t bi = static_cast<size_t>(bb);
    if (table[bi].stack <= 0)
        return false;

    acting_seat_ = bb;
    flush_ui();
    bot_action_pause();
    acting_seat_ = -1;
    const card &bc1 = table[bi].first_card;
    const card &bc2 = table[bi].second_card;
    const double wr_bb = seat_cfg_[bi].range_raise.weight(bc1, bc2);
    const double play_bb = play_weight_cards(seat_cfg_[bi], bc1, bc2);
    const bool raise = seat_cfg_[bi].strategy == BotStrategy::AlwaysCall
                           ? false
                           : bot_bb_check_or_raise_p(seat_cfg_[bi].params, play_bb, rng_);
    const int inc = min_raise_increment_chips(big_blind, last_raise_increment_);
    const int max_c = max_street_contrib();
    if (raise && inc > 0 && table[bi].stack >= inc && max_c == big_blind
        && rng_passes_layer_gate(wr_bb, play_bb, rng_))
    {
        const int taken_bb = table[bi].take_from_stack(inc);
        add_chips_to_pot(static_cast<int>(bb), taken_bb);
        street_contrib_[bi] += taken_bb;
        last_raise_increment_ = inc;
        if (table[bi].stack <= 0 && taken_bb > 0)
            set_seat_street_action(static_cast<int>(bb), QStringLiteral("All-in $%1").arg(taken_bb));
        else
            set_seat_street_action(static_cast<int>(bb),
                                   QStringLiteral("Raise to $%1").arg(static_cast<int>(street_contrib_[bi])));
        emit pot_changed();
        return true;
    }
    set_seat_street_action(static_cast<int>(bb), QStringLiteral("Check"));
    return false;
}

void game::note_river_aggressor(Street st, int seat)
{
    if (st == Street::RIVER)
    {
        river_last_aggressor_ = seat;
        river_had_bet_or_raise_ = true;
    }
}

void game::award_pot_to_last_standing()
{
    if (count_active() != 1)
        return;
    int winner = -1;
    for (int i = 0; i < players_count(); ++i)
    {
        if (in_hand_[static_cast<size_t>(i)])
        {
            winner = i;
            break;
        }
    }
    if (winner < 0)
        return;

    const QString msg = hand_result_status_line(winner);
    award_pot_to_seat(winner);
    set_hand_result_status(msg, result_banner_card_assets_for_seat(winner));
}

bool game::run_street_betting(Street st)
{
    const int n = players_count();
    if (n < 2 || count_active() < 2)
        return false;

    if (st == Street::RIVER)
    {
        river_last_aggressor_ = -1;
        river_had_bet_or_raise_ = false;
    }

    if (st != Street::PRE_FLOP)
        reset_postflop_street_contrib();

    for (;;)
    {
        const int max_c = max_street_contrib();
        const std::vector<int> order = action_order(st);

        int first_behind = -1;
        for (int seat : order)
        {
            if (!in_hand_[static_cast<size_t>(seat)])
                continue;
            const int need = max_c - street_contrib_[static_cast<size_t>(seat)];
            if (need <= 0)
                continue;
            /// Skip all-in players who already put everything in this street (side-pot case).
            if (table[static_cast<size_t>(seat)].stack <= 0)
                continue;
            first_behind = seat;
            break;
        }

        if (first_behind >= 0)
        {
            handle_forced_response(first_behind, st, max_c);
            if (count_active() <= 1)
            {
                award_pot_to_last_standing();
                return false;
            }
            continue;
        }

        if (st != Street::PRE_FLOP && max_c == 0)
        {
            const bool someone_bet = handle_postflop_check_or_bet(st);
            if (count_active() <= 1)
            {
                award_pot_to_last_standing();
                return false;
            }
            if (someone_bet)
                continue;
            emit pot_changed();
            return true;
        }

        if (st == Street::PRE_FLOP && max_c == big_blind && bb_preflop_option_open_)
        {
            const bool bb_raised = handle_bb_preflop_option();
            if (count_active() <= 1)
            {
                award_pot_to_last_standing();
                return false;
            }
            if (bb_raised)
                continue;
            emit pot_changed();
            return true;
        }

        emit pot_changed();
        return true;
    }
}

void game::award_pot_to_seat(int seat)
{
    if (seat < 0 || seat >= players_count())
        return;
    table[static_cast<size_t>(seat)].stack += pot;
    pot = 0;
    emit pot_changed();
}

std::string game::evaluator(const std::vector<card> &hand)
{
    return describe_hand_score(best_hand_score(hand));
}

void game::decide_the_payout()
{
    // Full automated hands pay out in do_payouts() from start(). This hook is kept for tests
    // that build a board manually without running start().
    if (players_count() < 2)
        return;
    do_payouts();
}

void game::do_payouts()
{
    const int n = players_count();
    if (n < 2 || pot <= 0)
        return;

    std::vector<int> contenders;
    contenders.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i)
    {
        if (in_hand_[static_cast<size_t>(i)])
            contenders.push_back(i);
    }

    if (contenders.empty())
        return;

    std::vector<std::vector<card>> hole_vecs;
    hole_vecs.reserve(contenders.size());
    for (int s : contenders)
        hole_vecs.push_back(get_hand_vector(s));

    if (contenders.size() == 1)
    {
        const int s = contenders.front();
        table[static_cast<size_t>(s)].stack += pot;
        const QString msg = hand_result_status_line(s);
        pot = 0;
        emit pot_changed();
        set_hand_result_status(msg, result_banner_card_assets_for_seat(s));
        return;
    }

    std::vector<int> contrib(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i)
        contrib[static_cast<size_t>(i)] = hand_contrib_[static_cast<size_t>(i)];

    std::vector<int> levels;
    std::vector<int> side_pot_amounts;
    const bool use_side_pots = holdem_nlhe_side_pot_breakdown(contrib, pot, &levels, &side_pot_amounts);

    if (use_side_pots)
    {
        std::array<int, kMaxPlayers> stack_gain{};
        stack_gain.fill(0);
        int distributed = 0;
        QStringList side_pot_status_lines;

        auto best_hands_among = [this](std::vector<int> seats) -> std::vector<int> {
            if (seats.empty())
                return {};
            std::sort(seats.begin(), seats.end());
            std::vector<int> winners = {seats.front()};
            for (size_t e = 1; e < seats.size(); ++e)
            {
                const int cmp = compare_holdem_hands(get_hand_vector(seats[e]), get_hand_vector(winners.front()));
                if (cmp > 0)
                    winners = {seats[e]};
                else if (cmp == 0)
                    winners.push_back(seats[e]);
            }
            std::sort(winners.begin(), winners.end());
            return winners;
        };

        for (size_t ti = 0; ti < levels.size(); ++ti)
        {
            const int level = levels[ti];
            const int side_pot = side_pot_amounts[ti];
            if (side_pot <= 0)
                continue;

            /// Seats still in the showdown that have matched at least `level` this hand win this slice.
            /// If every seat that contributed ≥ `level` has folded, award the slice among all remaining
            /// contenders (their chips stay in the middle; standard “orphan” side-pot resolution).
            std::vector<int> eligible;
            for (int s : contenders)
            {
                if (contrib[static_cast<size_t>(s)] >= level)
                    eligible.push_back(s);
            }
            if (eligible.empty())
                eligible = contenders;

            const std::vector<int> pot_winners = best_hands_among(std::move(eligible));

            const int nw = static_cast<int>(pot_winners.size());
            const int share = side_pot / nw;
            const int rem = side_pot % nw;
            for (int w = 0; w < nw; ++w)
                stack_gain[static_cast<size_t>(pot_winners[static_cast<size_t>(w)])] += share + (w < rem ? 1 : 0);
            distributed += side_pot;

            if (levels.size() > 1)
            {
                const QString seg_name =
                    (ti == 0 ? QStringLiteral("Main pot") : QStringLiteral("Side pot %1").arg(static_cast<int>(ti)));
                QString seg_body;
                if (pot_winners.size() == 1)
                {
                    const int ts = pot_winners.front();
                    seg_body = seat_display_name(ts);
                    const QString wn = winning_hand_label(ts);
                    if (!wn.isEmpty())
                        seg_body += QStringLiteral(" — ") + wn;
                    seg_body += QStringLiteral(" — ") + hole_cards_display(ts);
                }
                else
                {
                    QString hl;
                    for (int ts : pot_winners)
                    {
                        if (!hl.isEmpty())
                            hl += QStringLiteral(" · ");
                        hl += QStringLiteral("%1 %2").arg(seat_display_name(ts)).arg(hole_cards_display(ts));
                    }
                    const QString wn = winning_hand_label(pot_winners.front());
                    if (!wn.isEmpty())
                        seg_body = hl + QStringLiteral(" — ") + wn;
                    else
                        seg_body = hl;
                }
                side_pot_status_lines.append(QStringLiteral("%1 ($%2): %3").arg(seg_name).arg(side_pot).arg(seg_body));
            }
        }

        if (distributed < pot)
        {
            const int remainder = pot - distributed;
            if (remainder > 0)
            {
                const std::vector<int> rw = best_hands_among(contenders);
                if (!rw.empty())
                {
                    const int nw = static_cast<int>(rw.size());
                    const int share = remainder / nw;
                    const int rem = remainder % nw;
                    for (int w = 0; w < nw; ++w)
                        stack_gain[static_cast<size_t>(rw[static_cast<size_t>(w)])] += share + (w < rem ? 1 : 0);
                    distributed += remainder;
                }
            }
        }

        if (distributed == pot)
        {
            for (int i = 0; i < n; ++i)
                table[static_cast<size_t>(i)].stack += stack_gain[static_cast<size_t>(i)];
            pot = 0;
            emit pot_changed();

            std::vector<size_t> win_idx = {0};
            for (size_t w = 1; w < contenders.size(); ++w)
            {
                const int cmp = compare_holdem_hands(hole_vecs[w], hole_vecs[win_idx.front()]);
                if (cmp > 0)
                    win_idx = {w};
                else if (cmp == 0)
                    win_idx.push_back(w);
            }
            const int banner_seat = contenders[win_idx.front()];

            if (levels.size() > 1 && !side_pot_status_lines.isEmpty())
            {
                QString msg = side_pot_status_lines.join(QLatin1Char('\n'));
                const QString brd = board_compact_for_result();
                if (!brd.isEmpty())
                    msg += QLatin1Char('\n') + brd;
                set_hand_result_status(msg, result_banner_card_assets_for_seat(banner_seat));
                return;
            }

            std::vector<int> winners;
            for (size_t i : win_idx)
                winners.push_back(contenders[i]);

            QString msg;
            if (winners.size() == 1)
            {
                const int wseat = winners.front();
                msg = hand_result_status_line(wseat);
            }
            else
            {
                QString holes_line;
                for (int wseat : winners)
                {
                    if (!holes_line.isEmpty())
                        holes_line += QStringLiteral(" · ");
                    holes_line += QStringLiteral("%1 %2")
                                      .arg(seat_display_name(wseat))
                                      .arg(hole_cards_display(wseat));
                }
                msg = holes_line;
                {
                    const QString hn = winning_hand_label(winners.front());
                    if (!hn.isEmpty())
                        msg += QStringLiteral(" — ") + hn;
                    const QString brd = board_compact_for_result();
                    if (!brd.isEmpty())
                        msg += QStringLiteral(" · ") + brd;
                }
            }
            set_hand_result_status(msg, result_banner_card_assets_for_seat(banner_seat));
            return;
        }
    }

    std::vector<size_t> win_idx = {0};
    for (size_t w = 1; w < contenders.size(); ++w)
    {
        const int cmp = compare_holdem_hands(hole_vecs[w], hole_vecs[win_idx.front()]);
        if (cmp > 0)
            win_idx = {w};
        else if (cmp == 0)
            win_idx.push_back(w);
    }

    std::vector<int> winners;
    winners.reserve(win_idx.size());
    for (size_t i : win_idx)
        winners.push_back(contenders[i]);

    const int nw = static_cast<int>(winners.size());
    const int share = pot / nw;
    const int rem = pot % nw;
    for (int i = 0; i < nw; ++i)
        table[static_cast<size_t>(winners[static_cast<size_t>(i)])].stack += share + (i < rem ? 1 : 0);

    QString msg;
    if (winners.size() == 1)
    {
        const int wseat = winners.front();
        msg = hand_result_status_line(wseat);
    }
    else
    {
        QString holes_line;
        for (int wseat : winners)
        {
            if (!holes_line.isEmpty())
                holes_line += QStringLiteral(" · ");
            holes_line += QStringLiteral("%1 %2")
                              .arg(seat_display_name(wseat))
                              .arg(hole_cards_display(wseat));
        }
        msg = holes_line;
        {
            const QString hn = winning_hand_label(winners.front());
            if (!hn.isEmpty())
                msg += QStringLiteral(" — ") + hn;
            const QString brd = board_compact_for_result();
            if (!brd.isEmpty())
                msg += QStringLiteral(" · ") + brd;
        }
    }

    pot = 0;
    emit pot_changed();

    set_hand_result_status(msg, result_banner_card_assets_for_seat(winners.front()));
}

void game::switch_button()
{
    const int n = players_count();
    if (n <= 0)
        return;
    const int next = next_seat_in_position_pool(button);
    if (next >= 0)
        button = next;
}

void game::start()
{
    const int n = players_count();
    for (int i = 0; i < n; ++i)
        in_hand_[static_cast<size_t>(i)] = table[static_cast<size_t>(i)].stack > 0;
    if (human_sitting_out_)
        in_hand_[static_cast<size_t>(kHumanSeat)] = false;
    for (int s = 1; s < n; ++s)
    {
        if (!seat_participating_[static_cast<size_t>(s)])
            in_hand_[static_cast<size_t>(s)] = false;
    }

    if (count_active() < 2)
    {
        clear_for_new_hand();
        in_progress = false;
        try_auto_rebuys_for_busted_bots();
        if (m_root)
        {
            m_root->setProperty(
                "statusText",
                QStringLiteral("Need at least two players in the hand. Sit in to play or add players."));
            m_root->setProperty("resultBannerCardAssets", QVariantList());
        }
        flush_ui();
        return;
    }

    ensure_button_on_eligible_seat();

    clear_for_new_hand();
    in_progress = true;
    street = Street::PRE_FLOP;
    flush_ui();

    collect_blinds();
    init_preflop_street_contrib();
    deal_hold_cards();
    flush_ui();

    if (!run_street_betting(Street::PRE_FLOP))
    {
        switch_button();
        in_progress = false;
        ui_showdown_ = true;
        flush_ui();
        complete_hand_idle();
        return;
    }

    street = Street::FLOP;
    deal_flop();
    flush_ui();

    if (!run_street_betting(Street::FLOP))
    {
        switch_button();
        in_progress = false;
        ui_showdown_ = true;
        flush_ui();
        complete_hand_idle();
        return;
    }

    street = Street::TURN;
    deal_turn();
    flush_ui();

    if (!run_street_betting(Street::TURN))
    {
        switch_button();
        in_progress = false;
        ui_showdown_ = true;
        flush_ui();
        complete_hand_idle();
        return;
    }

    street = Street::RIVER;
    deal_river();
    flush_ui();

    if (!run_street_betting(Street::RIVER))
    {
        switch_button();
        in_progress = false;
        ui_showdown_ = true;
        flush_ui();
        complete_hand_idle();
        return;
    }

    do_payouts();
    switch_button();
    in_progress = false;
    ui_showdown_ = true;
    flush_ui();
    complete_hand_idle();
}

void game::beginNewHand()
{
    if (pending_seat_buyins_apply_ && !in_progress)
    {
        // Apply updated buy-ins right before the next hand begins.
        apply_seat_buy_ins_to_table();
        pending_seat_buyins_apply_ = false;
        flush_ui();
    }
    start();
}

void game::setRootObject(QObject *root)
{
    if (m_root != nullptr)
        m_root->disconnect(this);

    m_root = root;

    if (m_root)
        connect(m_root, SIGNAL(buttonClicked(QString)), this, SLOT(buttonClicked(QString)));

    clear_for_new_hand();
    sync_ui();
}

void game::clear_street_action_labels()
{
    seat_street_action_label_.fill(QString());
}

void game::set_seat_street_action(int seat, const QString &label)
{
    if (seat >= 0 && seat < kMaxPlayers)
        seat_street_action_label_[static_cast<size_t>(seat)] = label;
}

void game::push_human_action_status(const QString &actionLabel)
{
    (void)actionLabel;
}

QString game::board_compact_for_result() const
{
    if (flop.size() < 3)
        return {};
    QString out = card_to_display_string(flop[0]) + QLatin1Char(' ') + card_to_display_string(flop[1])
        + QLatin1Char(' ') + card_to_display_string(flop[2]);
    if (street >= Street::TURN)
        out += QLatin1Char(' ') + card_to_display_string(turn);
    if (street >= Street::RIVER)
        out += QLatin1Char(' ') + card_to_display_string(river);
    return out;
}

QStringList game::result_banner_card_assets_for_seat(int seat) const
{
    if (seat < 0 || seat >= players_count())
        return {};
    const std::vector<card> pool = cards_for_strength(seat, street);
    if (pool.size() < 2)
        return {};
    const std::vector<card> pick = best_five_cards_for_display(pool);
    QStringList out;
    out.reserve(static_cast<int>(pick.size()));
    for (const card &c : pick)
        out.push_back(card_to_qml_asset_path(c));
    return out;
}

void game::set_hand_result_status(const QString &msg, const QStringList &cardAssets)
{
    last_hand_result_message_ = msg;
    last_hand_result_card_assets_ = cardAssets;
    if (m_root)
    {
        m_root->setProperty("statusText", msg);
        m_root->setProperty("resultBannerCardAssets", QVariant::fromValue(cardAssets));
    }
}

void game::clear_for_new_hand()
{
    clear_street_action_labels();
    if (m_root)
    {
        /// Re-apply last result so QML keeps winner line + banner cards until the next showdown updates them.
        /// (Clearing to empty broke the GameControls banner after we stopped pushing stale text elsewhere.)
        m_root->setProperty("statusText", last_hand_result_message_);
        m_root->setProperty("resultBannerCardAssets", QVariant::fromValue(last_hand_result_card_assets_));
    }
    ui_showdown_ = false;
    pot = 0;
    hand_contrib_.fill(0);
    flop.clear();
    deck = card_deck{};
    acting_seat_ = -1;
    decision_seconds_left_ = 0;
    waiting_for_human_ = false;
    waiting_for_human_check_ = false;
    waiting_for_human_bb_preflop_ = false;
    sb_seat_ = -1;
    bb_seat_ = -1;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    cards_dealt_ = false;
    river_last_aggressor_ = -1;
    river_had_bet_or_raise_ = false;
    ++hand_seq_;
    emit pot_changed();
}

void game::apply_seat_buy_ins_to_table()
{
    const int cap = maxBuyInChips();
    for (size_t i = 0; i < table.size(); ++i)
    {
        seat_buy_in_[i] = std::max(1, std::min(seat_buy_in_[i], cap));
        const int bi = seat_buy_in_[i];
        const int total_wealth = table[i].stack + seat_wallet_[i];
        int on_table = std::min(bi, cap);
        if (on_table > total_wealth)
            on_table = total_wealth;
        seat_wallet_[i] = total_wealth - on_table;
        table[i].reset_stack(on_table);
    }
    init_bankroll_after_configure();
}

int game::maxBuyInChips() const
{
    return 100 * std::max(1, big_blind);
}

int game::seatBankrollTotal(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    const size_t si = static_cast<size_t>(seat);
    if (pending_bankroll_total_[si] >= 0)
        return pending_bankroll_total_[si];
    return table[si].stack + seat_wallet_[si];
}

bool game::pendingSeatBankrollApply() const
{
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        if (pending_bankroll_total_[static_cast<size_t>(i)] >= 0)
            return true;
    }
    return false;
}

int game::seatBuyIn(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return starting_stack_;
    return seat_buy_in_[static_cast<size_t>(seat)];
}

void game::setSeatBuyIn(int seat, int chips)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int cap = maxBuyInChips();
    int capped = std::min(chips, cap);
    capped = std::min(capped, 100000000);
    seat_buy_in_[static_cast<size_t>(seat)] = std::max(1, capped);
    // If a hand is currently running, wait until the next hand to re-apply stacks.
    if (in_progress)
        pending_seat_buyins_apply_ = true;
    notifySessionStatsChanged();
}

void game::applySeatBuyInsToStacks()
{
    if (in_progress)
        return;
    apply_seat_buy_ins_to_table();
    pending_seat_buyins_apply_ = false;
    flush_ui();
}

void game::configure(int sb, int bb, int streetBet, int startStack)
{
    small_blind = sb;
    big_blind = bb;
    street_bet_ = streetBet;
    const int cap = maxBuyInChips();
    starting_stack_ = std::max(1, std::min(startStack, cap));
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        seat_buy_in_[static_cast<size_t>(i)] =
            std::max(1, std::min(seat_buy_in_[static_cast<size_t>(i)], cap));
    }
    /// Per-seat buy-ins are edited in setup; stakes apply only blinds and re-push existing `seat_buy_in_` to stacks.
    apply_seat_buy_ins_to_table();
    if (m_root)
    {
        m_root->setProperty("smallBlind", small_blind);
        m_root->setProperty("bigBlind", big_blind);
    }
}

namespace {

constexpr char kSettingsV1[] = "v1";

int clamp_int(int v, int lo, int hi)
{
    return std::max(lo, std::min(hi, v));
}

} // namespace

int game::seatStrategyIndex(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    return static_cast<int>(seat_cfg_[static_cast<size_t>(seat)].strategy);
}

void game::loadPersistedSettings()
{
    QSettings store;
    store.beginGroup(QString::fromLatin1(kSettingsV1));
    if (!store.contains(QStringLiteral("smallBlind")))
    {
        store.endGroup();
        return;
    }

    const int sb = clamp_int(store.value(QStringLiteral("smallBlind")).toInt(), 1, 500);
    const int bb = clamp_int(store.value(QStringLiteral("bigBlind")).toInt(), 1, 500);
    const int st = clamp_int(store.value(QStringLiteral("streetBet")).toInt(), 1, 100000);
    const int stack = clamp_int(store.value(QStringLiteral("startStack")).toInt(), 20, 1000000);
    configure(sb, bb, st, stack);

    const int cap = maxBuyInChips();
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        const QString bik = QStringLiteral("seat%1/buyIn").arg(i);
        if (store.contains(bik))
            seat_buy_in_[static_cast<size_t>(i)] = clamp_int(store.value(bik).toInt(), 1, cap);
        else
            seat_buy_in_[static_cast<size_t>(i)] = std::min(stack, cap); // legacy: global startStack
    }
    apply_seat_buy_ins_to_table();

    for (int i = 0; i < kMaxPlayers; ++i)
    {
        const QString wk = QStringLiteral("seat%1/wallet").arg(i);
        if (store.contains(wk))
            seat_wallet_[static_cast<size_t>(i)] = clamp_int(store.value(wk).toInt(), 0, 100000000);
    }
    {
        const int n = players_count();
        for (int i = 0; i < n; ++i)
            session_baseline_[static_cast<size_t>(i)] =
                table[static_cast<size_t>(i)].stack + seat_wallet_[static_cast<size_t>(i)];
        bankroll_history_.clear();
        bankroll_snapshot_times_ms_.clear();
        record_bankroll_snapshot();
    }

    const int stratMax = static_cast<int>(BotStrategy::Count) - 1;
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        const int strat = clamp_int(store.value(QStringLiteral("seat%1/strategy").arg(i)).toInt(), 0, stratMax);
        setSeatStrategy(i, strat);
        const QString rt = store.value(QStringLiteral("seat%1/rangeText").arg(i)).toString();
        if (!rt.isEmpty())
            applySeatRangeText(i, rt, 0);
        const QString rtr = store.value(QStringLiteral("seat%1/rangeTextRaise").arg(i)).toString();
        const QString rtb = store.value(QStringLiteral("seat%1/rangeTextBet").arg(i)).toString();
        SeatBot &sb = seat_cfg_[static_cast<size_t>(i)];
        if (!rtr.isEmpty())
            applySeatRangeText(i, rtr, 1);
        else
            sb.range_raise = sb.range_call;
        if (!rtb.isEmpty())
            applySeatRangeText(i, rtb, 2);
        else
            sb.range_bet = sb.range_call;

        const QString pfx = QStringLiteral("seat%1/").arg(i);
        QVariantMap pm;
        if (store.contains(pfx + QStringLiteral("preflopExponent")))
            pm.insert(QStringLiteral("preflopExponent"), store.value(pfx + QStringLiteral("preflopExponent")));
        if (store.contains(pfx + QStringLiteral("postflopExponent")))
            pm.insert(QStringLiteral("postflopExponent"), store.value(pfx + QStringLiteral("postflopExponent")));
        if (store.contains(pfx + QStringLiteral("facingRaiseBonus")))
            pm.insert(QStringLiteral("facingRaiseBonus"), store.value(pfx + QStringLiteral("facingRaiseBonus")));
        if (store.contains(pfx + QStringLiteral("facingRaiseTightMul")))
            pm.insert(QStringLiteral("facingRaiseTightMul"), store.value(pfx + QStringLiteral("facingRaiseTightMul")));
        if (store.contains(pfx + QStringLiteral("openBetBonus")))
            pm.insert(QStringLiteral("openBetBonus"), store.value(pfx + QStringLiteral("openBetBonus")));
        if (store.contains(pfx + QStringLiteral("openBetTightMul")))
            pm.insert(QStringLiteral("openBetTightMul"), store.value(pfx + QStringLiteral("openBetTightMul")));
        if (store.contains(pfx + QStringLiteral("bbCheckraiseBonus")))
            pm.insert(QStringLiteral("bbCheckraiseBonus"), store.value(pfx + QStringLiteral("bbCheckraiseBonus")));
        if (store.contains(pfx + QStringLiteral("bbCheckraiseTightMul")))
            pm.insert(QStringLiteral("bbCheckraiseTightMul"), store.value(pfx + QStringLiteral("bbCheckraiseTightMul")));
        if (!pm.isEmpty())
            setSeatStrategyParams(i, pm);
    }

    setHumanSitOut(store.value(QStringLiteral("humanSitOut"), false).toBool());
    setBotSlowActions(store.value(QStringLiteral("botSlowActions"), false).toBool());
    for (int s = 1; s < kMaxPlayers; ++s)
    {
        const bool def = true;
        setSeatParticipating(s, store.value(QStringLiteral("seat%1/participating").arg(s), def).toBool());
    }
    store.endGroup();
}

void game::savePersistedSettings() const
{
    QSettings store;
    store.beginGroup(QString::fromLatin1(kSettingsV1));
    store.setValue(QStringLiteral("smallBlind"), small_blind);
    store.setValue(QStringLiteral("bigBlind"), big_blind);
    store.setValue(QStringLiteral("streetBet"), street_bet_);
    store.setValue(QStringLiteral("startStack"), starting_stack_);
    store.setValue(QStringLiteral("humanSitOut"), human_sitting_out_);
    store.setValue(QStringLiteral("botSlowActions"), bot_slow_actions_);
    for (int s = 1; s < kMaxPlayers; ++s)
        store.setValue(QStringLiteral("seat%1/participating").arg(s), seat_participating_[static_cast<size_t>(s)]);

    for (int i = 0; i < kMaxPlayers; ++i)
    {
        store.setValue(QStringLiteral("seat%1/strategy").arg(i), seatStrategyIndex(i));
        store.setValue(QStringLiteral("seat%1/rangeText").arg(i), exportSeatRangeText(i, 0));
        store.setValue(QStringLiteral("seat%1/rangeTextRaise").arg(i), exportSeatRangeText(i, 1));
        store.setValue(QStringLiteral("seat%1/rangeTextBet").arg(i), exportSeatRangeText(i, 2));
        store.setValue(QStringLiteral("seat%1/buyIn").arg(i), seat_buy_in_[static_cast<size_t>(i)]);
        store.setValue(QStringLiteral("seat%1/wallet").arg(i), seat_wallet_[static_cast<size_t>(i)]);
        const BotParams &bp = seat_cfg_[static_cast<size_t>(i)].params;
        const QString pfx = QStringLiteral("seat%1/").arg(i);
        store.setValue(pfx + QStringLiteral("preflopExponent"), bp.preflop_exponent);
        store.setValue(pfx + QStringLiteral("postflopExponent"), bp.postflop_exponent);
        store.setValue(pfx + QStringLiteral("facingRaiseBonus"), bp.facing_raise_bonus);
        store.setValue(pfx + QStringLiteral("facingRaiseTightMul"), bp.facing_raise_tight_mul);
        store.setValue(pfx + QStringLiteral("openBetBonus"), bp.open_bet_bonus);
        store.setValue(pfx + QStringLiteral("openBetTightMul"), bp.open_bet_tight_mul);
        store.setValue(pfx + QStringLiteral("bbCheckraiseBonus"), bp.bb_checkraise_bonus);
        store.setValue(pfx + QStringLiteral("bbCheckraiseTightMul"), bp.bb_checkraise_tight_mul);
    }
    store.endGroup();
    store.sync();
}

void game::setSeatStrategy(int seat, int strategyIndex)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int n = static_cast<int>(BotStrategy::Count);
    if (strategyIndex < 0 || strategyIndex >= n)
        return;
    const auto strat = static_cast<BotStrategy>(strategyIndex);
    const size_t si = static_cast<size_t>(seat);
    seat_cfg_[si].strategy = strat;
    seat_cfg_[si].params = params_for(strat);
    fill_preset_range(seat_cfg_[si].range_call, strat);
    seat_cfg_[si].range_raise = seat_cfg_[si].range_call;
    seat_cfg_[si].range_bet = seat_cfg_[si].range_call;
}

QVariantMap game::seatStrategyParams(int seat) const
{
    QVariantMap m;
    if (seat < 0 || seat >= kMaxPlayers)
        return m;
    const BotParams &p = seat_cfg_[static_cast<size_t>(seat)].params;
    m[QStringLiteral("preflopExponent")] = p.preflop_exponent;
    m[QStringLiteral("postflopExponent")] = p.postflop_exponent;
    m[QStringLiteral("facingRaiseBonus")] = p.facing_raise_bonus;
    m[QStringLiteral("facingRaiseTightMul")] = p.facing_raise_tight_mul;
    m[QStringLiteral("openBetBonus")] = p.open_bet_bonus;
    m[QStringLiteral("openBetTightMul")] = p.open_bet_tight_mul;
    m[QStringLiteral("bbCheckraiseBonus")] = p.bb_checkraise_bonus;
    m[QStringLiteral("bbCheckraiseTightMul")] = p.bb_checkraise_tight_mul;
    return m;
}

void game::setSeatStrategyParams(int seat, QVariantMap map)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    BotParams p = seat_cfg_[static_cast<size_t>(seat)].params;
    auto take = [&map](const char *key, double &dst) {
        const QString k = QString::fromLatin1(key);
        if (map.contains(k))
            dst = map.value(k).toDouble();
    };
    take("preflopExponent", p.preflop_exponent);
    take("postflopExponent", p.postflop_exponent);
    take("facingRaiseBonus", p.facing_raise_bonus);
    take("facingRaiseTightMul", p.facing_raise_tight_mul);
    take("openBetBonus", p.open_bet_bonus);
    take("openBetTightMul", p.open_bet_tight_mul);
    take("bbCheckraiseBonus", p.bb_checkraise_bonus);
    take("bbCheckraiseTightMul", p.bb_checkraise_tight_mul);
    seat_cfg_[static_cast<size_t>(seat)].params = clamp_bot_params(p);
}

QVariantList game::getPresetRangeGrid(int strategyIndex, int layer) const
{
    Q_UNUSED(layer);
    QVariantList list;
    const int n = static_cast<int>(BotStrategy::Count);
    if (strategyIndex < 0 || strategyIndex >= n)
        return list;
    RangeMatrix m;
    fill_preset_range(m, static_cast<BotStrategy>(strategyIndex));
    double buf[169];
    m.copy_to_flat(buf, 169);
    for (int i = 0; i < 169; ++i)
        list.append(buf[i]);
    return list;
}

QString game::getStrategySummary(int strategyIndex) const
{
    const int n = static_cast<int>(BotStrategy::Count);
    if (strategyIndex < 0 || strategyIndex >= n)
        return {};
    return QString::fromStdString(strategy_description(static_cast<BotStrategy>(strategyIndex)));
}

bool game::applySeatRangeText(int seat, const QString &text, int layer)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return false;
    return layer_matrix(seat_cfg_[static_cast<size_t>(seat)], layer)
        ->parse_text(text.toStdString());
}

void game::setRangeCell(int seat, int row, int col, double w, int layer)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    layer_matrix(seat_cfg_[static_cast<size_t>(seat)], layer)->set_cell(row, col, w);
}

void game::resetSeatRangeFull(int seat)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    SeatBot &sb = seat_cfg_[static_cast<size_t>(seat)];
    sb.range_call.fill(1.0);
    sb.range_raise.fill(1.0);
    sb.range_bet.fill(1.0);
}

void game::setSeatParticipating(int seat, bool participating)
{
    if (seat < 1 || seat >= kMaxPlayers)
        return;
    seat_participating_[static_cast<size_t>(seat)] = participating;
}

bool game::seatParticipating(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return true;
    return seat_participating_[static_cast<size_t>(seat)];
}

void game::setBotSlowActions(bool enabled)
{
    bot_slow_actions_ = enabled;
}

bool game::botSlowActions() const
{
    return bot_slow_actions_;
}

void game::setBotActionDelayEnabled(bool enabled)
{
    bot_action_delay_enabled_ = enabled;
}

QVariantList game::getRangeGrid(int seat, int layer) const
{
    QVariantList list;
    if (seat < 0 || seat >= kMaxPlayers)
        return list;
    double buf[169];
    layer_matrix_c(seat_cfg_[static_cast<size_t>(seat)], layer)->copy_to_flat(buf, 169);
    for (int i = 0; i < 169; ++i)
        list.append(buf[i]);
    return list;
}

QString game::exportSeatRangeText(int seat, int layer) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return {};
    return QString::fromStdString(
        layer_matrix_c(seat_cfg_[static_cast<size_t>(seat)], layer)->export_text());
}

void game::notifySessionStatsChanged()
{
    ++stats_seq_;
    emit sessionStatsChanged();
}

void game::record_bankroll_snapshot()
{
    std::array<int, kMaxPlayers> snap{};
    const int n = players_count();
    for (int i = 0; i < n; ++i)
        snap[static_cast<size_t>(i)] = table[static_cast<size_t>(i)].stack
                                        + seat_wallet_[static_cast<size_t>(i)];
    bankroll_history_.push_back(snap);
    bankroll_snapshot_times_ms_.push_back(QDateTime::currentMSecsSinceEpoch());
    ++stats_seq_;
    emit sessionStatsChanged();
}

void game::init_bankroll_after_configure()
{
    bankroll_history_.clear();
    bankroll_snapshot_times_ms_.clear();
    const int n = players_count();
    for (int i = 0; i < n; ++i)
        session_baseline_[static_cast<size_t>(i)] =
            table[static_cast<size_t>(i)].stack + seat_wallet_[static_cast<size_t>(i)];
    record_bankroll_snapshot();
}

void game::complete_hand_idle()
{
    try_auto_rebuys_for_busted_bots();
    flush_pending_bankroll_totals();
    record_bankroll_snapshot();
    sync_seat_buy_in_from_table_when_wallet_empty();
    savePersistedSettings();
    flush_ui();
    schedule_next_hand_if_idle();
}

int game::seatWallet(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    return seat_wallet_[static_cast<size_t>(seat)];
}

bool game::canBuyBackIn(int seat) const
{
    if (seat < 0 || seat >= players_count())
        return false;
    const size_t si = static_cast<size_t>(seat);
    if (in_progress && in_hand_[si])
        return false;
    if (table[si].stack > 0)
        return false;
    return seat_wallet_[si] >= seat_buy_in_[si];
}

bool game::tryBuyBackIn(int seat)
{
    if (!apply_buy_back_in_internal(seat))
        return false;
    record_bankroll_snapshot();
    savePersistedSettings();
    flush_ui();
    return true;
}

QVariantList game::seatRankings() const
{
    struct Row
    {
        int seat;
        int table_stack;
        int wallet;
        int total;
    };
    std::vector<Row> rows;
    const int n = players_count();
    rows.reserve(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i)
    {
        const int st = table[static_cast<size_t>(i)].stack;
        const int w = seat_wallet_[static_cast<size_t>(i)];
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

QVariantList game::bankrollSeries(int seat) const
{
    QVariantList out;
    if (seat < 0 || seat >= kMaxPlayers)
        return out;
    const size_t si = static_cast<size_t>(seat);
    for (const auto &snap : bankroll_history_)
        out.append(snap[si]);
    return out;
}

int game::bankrollSnapshotCount() const
{
    return static_cast<int>(bankroll_history_.size());
}

QVariantList game::bankrollSnapshotTimesMs() const
{
    QVariantList out;
    for (qint64 t : bankroll_snapshot_times_ms_)
        out.append(static_cast<qlonglong>(t));
    return out;
}

void game::sync_seat_buy_in_from_table_when_wallet_empty()
{
    if (in_progress)
        return;
    const int n = players_count();
    const int cap = maxBuyInChips();
    for (int i = 0; i < n; ++i)
    {
        const size_t si = static_cast<size_t>(i);
        if (seat_wallet_[si] < 1 && table[si].stack > 0)
            seat_buy_in_[si] = std::min(table[si].stack, cap);
    }
}

void game::flush_pending_bankroll_totals()
{
    if (in_progress)
        return;
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        const int pending = pending_bankroll_total_[static_cast<size_t>(i)];
        if (pending >= 0)
        {
            apply_seat_bankroll_total_now(i, pending);
            pending_bankroll_total_[static_cast<size_t>(i)] = -1;
        }
    }
}

void game::applyPendingBankrollTotals()
{
    flush_pending_bankroll_totals();
}

void game::apply_seat_bankroll_total_now(int seat, int totalChips)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int t = std::max(1, std::min(100000000, totalChips));
    const size_t si = static_cast<size_t>(seat);
    const int cap = maxBuyInChips();
    const int on_table = std::min(t, cap);
    seat_buy_in_[si] = on_table;
    table[si].reset_stack(on_table);
    seat_wallet_[si] = t - on_table;
    record_bankroll_snapshot();
    savePersistedSettings();
    flush_ui();
}

void game::setSeatBankrollTotal(int seat, int totalChips)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int t = std::max(1, std::min(100000000, totalChips));
    if (in_progress)
    {
        pending_bankroll_total_[static_cast<size_t>(seat)] = t;
        notifySessionStatsChanged();
        return;
    }
    apply_seat_bankroll_total_now(seat, t);
    pending_bankroll_total_[static_cast<size_t>(seat)] = -1;
}

int game::sessionBaselineStack(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    return session_baseline_[static_cast<size_t>(seat)];
}

void game::resetBankrollSession()
{
    const int n = players_count();
    for (int i = 0; i < n; ++i)
        session_baseline_[static_cast<size_t>(i)] =
            table[static_cast<size_t>(i)].stack + seat_wallet_[static_cast<size_t>(i)];
    bankroll_history_.clear();
    bankroll_snapshot_times_ms_.clear();
    record_bankroll_snapshot();
}

QVariantMap game::bettingAnchors() const
{
    QVariantMap m;
    int sb = -1;
    int bb = -1;
    compute_blind_seats(sb, bb);
    m.insert(QStringLiteral("sbSeat"), sb);
    m.insert(QStringLiteral("bbSeat"), bb);
    m.insert(QStringLiteral("preflopFirstSeat"), bb >= 0 ? first_in_hand_after(bb) : -1);
    m.insert(QStringLiteral("postflopFirstSeat"), first_in_hand_after(button));
    return m;
}

game::game(QObject *parent)
    : QObject(parent)
    , human_decision_tick_(this)
    , human_decision_deadline_(this)
{
    seat_participating_.fill(true);
    seat_buy_in_.fill(starting_stack_);
    seat_wallet_.fill(0);
    pending_bankroll_total_.fill(-1);
    for (int s = 0; s < kMaxPlayers; ++s)
    {
        player p;
        p.stack = seat_buy_in_[static_cast<size_t>(s)];
        p.first_card = card(Rank::TWO, Suite::CLUBS);
        p.second_card = card(Rank::THREE, Suite::CLUBS);
        join_table(p);
        seat_cfg_[static_cast<size_t>(s)].strategy = BotStrategy::AlwaysCall;
        seat_cfg_[static_cast<size_t>(s)].params = params_for(BotStrategy::AlwaysCall);
        seat_cfg_[static_cast<size_t>(s)].range_call.fill(1.0);
        seat_cfg_[static_cast<size_t>(s)].range_raise.fill(1.0);
        seat_cfg_[static_cast<size_t>(s)].range_bet.fill(1.0);
        in_hand_[static_cast<size_t>(s)] = true;
    }

    QObject::connect(this, &game::pot_changed, this, &game::on_pot_changed);

    const int n = players_count();
    for (int i = 0; i < n; ++i)
        session_baseline_[static_cast<size_t>(i)] =
            table[static_cast<size_t>(i)].stack + seat_wallet_[static_cast<size_t>(i)];
    record_bankroll_snapshot();
}

void game::buttonClicked(QString button)
{
    if (!m_root)
        return;
    if (button == QStringLiteral("MORE_TIME"))
    {
        requestMoreTime();
        return;
    }
    if (waiting_for_human_bb_preflop_)
    {
        if (button == QStringLiteral("CHECK"))
            finish_human_bb_preflop(false);
        return;
    }
    if (waiting_for_human_check_)
    {
        if (button == QStringLiteral("CHECK"))
            submitCheckOrBet(true, 0);
        else if (button == QStringLiteral("FOLD"))
            submitFoldFromCheck();
        return;
    }
    if (waiting_for_human_)
    {
        if (button == QStringLiteral("FOLD"))
            submitFacingAction(0, 0);
        else if (button == QStringLiteral("CALL"))
            submitFacingAction(1, 0);
        return;
    }
    if (button == QStringLiteral("CALL") || button == QStringLiteral("RAISE"))
        return;
    if (button == QStringLiteral("FOLD"))
        return;
}
