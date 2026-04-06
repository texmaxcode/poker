// Table engine: betting rounds, bots, blinds, persistence, human decision timers.
// QML-facing `sync_ui` / `flush_ui` live in game_ui_sync.cpp.

#include "game.hpp"

#include "hand_eval.hpp"
#include "holdem_side_pot.hpp"
#include "human_decision_controller.hpp"

#include "cards.hpp"

#include <algorithm>
#include <array>
#include <cassert>
#include <vector>
#include <cmath>
#include <random>

#include <QCoreApplication>
#include <QDateTime>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QThread>
#include "game_persistence.hpp"
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace {

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
    p.buy_in_bb = std::clamp(p.buy_in_bb, 1, 10000);
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
    /// Seats are always filled to `kMaxPlayers`; chips come from configure / buy-in apply (`start()` gates play).
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
        s = (s + n - 1) % n;
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

QString game::hole_cards_display(int seat) const
{
    if (seat < 0 || seat >= players_count())
        return {};
    return card_to_display_string(table[static_cast<size_t>(seat)].first_card) + QLatin1Char(' ')
        + card_to_display_string(table[static_cast<size_t>(seat)].second_card);
}

QString game::format_showdown_payout_lines_from_gains(const std::array<int, kMaxPlayers> &stack_gain,
                                                      int players_n) const
{
    QStringList lines;
    std::vector<int> seats;
    seats.reserve(static_cast<size_t>(players_n));
    for (int s = 0; s < players_n; ++s)
    {
        if (stack_gain[static_cast<size_t>(s)] > 0)
            seats.push_back(s);
    }
    std::sort(seats.begin(), seats.end(), [&](int a, int b) {
        const int ga = stack_gain[static_cast<size_t>(a)];
        const int gb = stack_gain[static_cast<size_t>(b)];
        if (ga != gb)
            return ga > gb;
        return a < b;
    });
    const QString brd = board_compact_for_result();
    const QString board_text = brd.isEmpty() ? QStringLiteral("—") : brd;
    for (int s : seats)
    {
        QString hand_name = winning_hand_label(s);
        if (hand_name.isEmpty())
            hand_name = QStringLiteral("—");
        lines.append(QStringLiteral("%1 $%2 with %3 on %4, %5")
                         .arg(seat_display_name(s))
                         .arg(stack_gain[static_cast<size_t>(s)])
                         .arg(hole_cards_display(s))
                         .arg(board_text)
                         .arg(hand_name));
    }
    return lines.join(QLatin1Char('\n'));
}

int game::banner_seat_from_showdown_gains(const std::array<int, kMaxPlayers> &stack_gain, int players_n) const
{
    int best_seat = -1;
    int best_amt = -1;
    for (int s = 0; s < players_n; ++s)
    {
        const int g = stack_gain[static_cast<size_t>(s)];
        if (g <= 0)
            continue;
        if (g > best_amt || (g == best_amt && (best_seat < 0 || s < best_seat)))
        {
            best_amt = g;
            best_seat = s;
        }
    }
    return best_seat >= 0 ? best_seat : 0;
}

QString game::fold_win_status_line(int seat, int pot_chips) const
{
    return QStringLiteral("%1 $%2 with %3")
        .arg(seat_display_name(seat))
        .arg(pot_chips)
        .arg(hole_cards_display(seat));
}

QString game::winning_hand_label(int seat) const
{
    const auto v = cards_for_strength(seat, street);
    if (v.size() < 2)
        return {};
    return QString::fromStdString(describe_holdem_hand(v));
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
        const int seat = (start + n - k) % n;
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

int game::count_eligible_players_for_deal_after_apply()
{
    if (!in_progress)
    {
        seat_mgr_.flush_pending_bankroll_totals();
        seat_mgr_.apply_seat_buy_ins_to_table(false);
    }
    int c = 0;
    const int n = players_count();
    for (int i = 0; i < n; ++i)
    {
        const size_t si = static_cast<size_t>(i);
        if (table[si].stack <= 0)
            continue;
        if (static_cast<int>(i) == kHumanSeat && human_sitting_out_)
            continue;
        if (i >= 1 && !seat_mgr_.seat_participating_[si])
            continue;
        ++c;
    }
    return c;
}

bool game::everyone_in_hand_is_all_in() const
{
    bool any_in_hand = false;
    for (int i = 0; i < players_count(); ++i)
    {
        if (!in_hand_[static_cast<size_t>(i)])
            continue;
        any_in_hand = true;
        if (table[static_cast<size_t>(i)].stack > 0)
            return false;
    }
    return any_in_hand;
}

bool game::heads_up_one_all_in_other_has_chips() const
{
    if (count_active() != 2)
        return false;
    int with_chips = 0;
    int all_in = 0;
    for (int i = 0; i < players_count(); ++i)
    {
        if (!in_hand_[static_cast<size_t>(i)])
            continue;
        if (table[static_cast<size_t>(i)].stack > 0)
            ++with_chips;
        else
            ++all_in;
    }
    return with_chips == 1 && all_in == 1;
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
    {
        preflop_blind_level_ = 0;
        return;
    }
    const size_t sbi = static_cast<size_t>(sb_seat_);
    const size_t bbi = static_cast<size_t>(bb_seat_);
    /// Must match `collect_blinds()` — short stacks post less than nominal SB/BB (`player::pay`).
    street_contrib_[sbi] = hand_contrib_[sbi];
    street_contrib_[bbi] = hand_contrib_[bbi];
    preflop_blind_level_ = std::max(street_contrib_[sbi], street_contrib_[bbi]);
    set_seat_street_action(sb_seat_, QStringLiteral("SB $%1").arg(street_contrib_[sbi]));
    set_seat_street_action(bb_seat_, QStringLiteral("BB $%1").arg(street_contrib_[bbi]));
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

void game::submitFacingAction(int action, int raiseChips)
{
    human_decision_ctrl_->submitFacingAction(action, raiseChips);
}

void game::submitCheckOrBet(bool check, int betChips)
{
    human_decision_ctrl_->submitCheckOrBet(check, betChips);
}

void game::submitFoldFromCheck()
{
    human_decision_ctrl_->submitFoldFromCheck();
}

void game::submitBbPreflopRaise(int chips_to_add)
{
    human_decision_ctrl_->submitBbPreflopRaise(chips_to_add);
}

void game::setInteractiveHuman(bool enabled)
{
    if (interactive_human_ == enabled)
        return;
    interactive_human_ = enabled;
    /// Autoplay uses your configured strategy; do not keep "sit out" (that state is for watching only).
    if (!enabled)
        setHumanSitOut(false);
    /// Seat 0 buy-in target follows `seat_buy_in_` when interactive; strategy `buy_in_bb` when autoplaying.
    if (!enabled)
        seat_mgr_.seat_buy_in_[static_cast<size_t>(kHumanSeat)] = effectiveSeatBuyInChips(kHumanSeat);
    emit interactiveHumanChanged();
    /// Materialize stacks from buy-in targets when idle (e.g. autoplay: auto-rebuy uses effective stack).
    if (persist_loaded_ && !suppress_persist_ && !in_progress)
        seat_mgr_.apply_seat_buy_ins_to_table(false);
}

void game::setHumanSitOut(bool enabled)
{
    human_sitting_out_ = enabled;
    if (m_root)
        m_root->setProperty("humanSittingOut", human_sitting_out_);
    if (enabled)
    {
        if (human_decision_ctrl_->isWaitingForHuman())
            human_decision_ctrl_->submitFacingAction(0, 0);
        else if (human_decision_ctrl_->isWaitingForHumanCheck())
            human_decision_ctrl_->submitFoldFromCheck();
        else if (human_decision_ctrl_->isWaitingForHumanBbPreflop())
            human_decision_ctrl_->finish_human_bb_preflop(false);
    }
    sync_ui();
}

int game::first_in_hand_after(int prev_seat) const
{
    const int n = players_count();
    if (n < 1)
        return -1;
    /// Next seat in **clockwise** poker order around the felt. `GameScreen` maps increasing seat index
    /// around the oval in the **counter-clockwise** direction, so clockwise is `(prev + n - 1) % n`.
    for (int k = 1; k <= n; ++k)
    {
        const int s = (prev_seat + n - k) % n;
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
    return seat_mgr_.seat_participating_[static_cast<size_t>(seat)];
}

int game::next_seat_in_position_pool(int from) const
{
    const int n = players_count();
    if (n < 1)
        return -1;
    for (int k = 1; k <= n; ++k)
    {
        const int s = (from + n - k) % n;
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
    // 3+ players: SB clockwise from button, BB clockwise from SB (standard ring).
    // Heads-up: button posts SB; the other seat posts BB.
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

void game::schedule_next_hand_if_idle()
{
    if (!auto_hand_loop_)
        return;
    /// Pause so showdown / winner lines and mucked or shown hands stay readable before the next deal.
    const int ms = std::clamp(winning_hand_show_ms_, 500, 60000);
    QTimer::singleShot(ms, this, [this]() {
        if (!m_root)
            return;
        beginNewHand();
    });
}


void game::bot_action_pause()
{
    if (!bot_action_delay_enabled_)
        return;
    if (!bot_slow_actions_)
        return;
    /// `flush_ui()` already ran `processEvents`; one more pass so the acting-seat highlight is queued.
    /// A plain `msleep` then blocked the GUI thread **without** processing events, so Qt Quick often
    /// showed the whole hand as one instant jump. Pump the event loop so each bot action can render
    /// before the next decision (`botDecisionDelaySec`, default 2 s).
    QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    QElapsedTimer t;
    t.start();
    const int kMs = std::clamp(bot_decision_delay_sec_, 1, 30) * 1000;
    while (t.elapsed() < kMs)
    {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 16);
        QThread::msleep(16);
    }
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

    /// Seat 0: only open the on-felt decision UI when interactive; otherwise use the same bot logic as seats 1–5.
    if (seat == kHumanSeat && interactive_human_ && m_root)
    {
        /// No chips behind — already all-in for this street; do not open the human action UI.
        if (table[si].stack <= 0)
            return true;

        acting_seat_ = seat;
        flush_ui();

        human_decision_ctrl_->wait_for_human_need(need, st, inc);
        acting_seat_ = -1;
        sync_ui();

        if (human_decision_ctrl_->humanFacingAction() == 0)
        {
            set_seat_street_action(seat, QStringLiteral("Fold"));
            in_hand_[si] = false;
            return true;
        }

        if (human_decision_ctrl_->humanFacingAction() == 2)
        {
            int chips = human_decision_ctrl_->humanFacingRaiseChips();
            if (chips <= 0)
                chips = need + inc;
            chips = std::min(chips, table[si].stack);
            if (chips <= 0)
            {
                set_seat_street_action(seat, QStringLiteral("Fold"));
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
                if (st == Street::PRE_FLOP && new_contrib > preflop_blind_level_)
                    bb_preflop_option_open_ = false;
                note_river_aggressor(st, seat);
                if (taken_raise >= stack_before_raise)
                    set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken_raise));
                else
                    set_seat_street_action(seat, QStringLiteral("Raise to $%1").arg(new_contrib));
            }
            else if (taken_raise >= stack_before_raise)
            {
                set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken_raise));
            }
            else
            {
                set_seat_street_action(seat, QStringLiteral("Call $%1").arg(taken_raise));
            }
            emit pot_changed();
            return true;
        }

        const int stack_before_call = table[si].stack;
        const int taken_call = table[si].take_from_stack(need);
        add_chips_to_pot(seat, taken_call);
        street_contrib_[si] += taken_call;
        if (taken_call >= stack_before_call)
            set_seat_street_action(seat, QStringLiteral("All-in $%1").arg(taken_call));
        else
            set_seat_street_action(seat, QStringLiteral("Call $%1").arg(taken_call));
        emit pot_changed();
        return true;
    }

    acting_seat_ = seat;
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
            if (st == Street::PRE_FLOP && new_max > preflop_blind_level_)
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
        if (seat == kHumanSeat && interactive_human_ && m_root)
        {
            if (human_decision_ctrl_->wait_for_human_check_or_bet(st))
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

    if (bb == kHumanSeat && interactive_human_ && m_root)
    {
        if (table[static_cast<size_t>(kHumanSeat)].stack <= 0)
            return false;
        return human_decision_ctrl_->wait_for_human_bb_preflop();
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
    if (raise && inc > 0 && table[bi].stack >= inc && max_c == preflop_blind_level_
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

void game::note_river_aggressor(Street /*st*/, int /*seat*/)
{
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

    const int won = pot;
    const QString msg = fold_win_status_line(winner, won);
    award_pot_to_seat(winner);
    set_hand_result_status(msg, result_banner_card_assets_for_seat(winner));
}

bool game::run_street_betting(Street st)
{
    const int n = players_count();
    if (n < 2 || count_active() < 2)
        return false;

    if (st != Street::PRE_FLOP)
        reset_postflop_street_contrib();

    /// No further betting when all stacks are in, or (postflop) HU with one all-in — run board out.
    /// Skip `heads_up…` on preflop so an all-in blind still leaves BB/SB action where rules require it.
    if (everyone_in_hand_is_all_in()
        || (st != Street::PRE_FLOP && heads_up_one_all_in_other_has_chips()))
    {
        emit pot_changed();
        return true;
    }

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

        if (st == Street::PRE_FLOP && max_c == preflop_blind_level_ && bb_preflop_option_open_)
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
        const int won = pot;
        table[static_cast<size_t>(s)].stack += pot;
        const QString msg = fold_win_status_line(s, won);
        pot = 0;
        emit pot_changed();
        set_hand_result_status(msg, result_banner_card_assets_for_seat(s));
        return;
    }

    std::vector<int> contrib(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i)
        contrib[static_cast<size_t>(i)] = hand_contrib_[static_cast<size_t>(i)];

    std::vector<NlheSidePotSlice> side_pots;
    const bool use_side_pots = nlhe_build_side_pot_slices(contrib, pot, &side_pots);

    if (use_side_pots)
    {
        std::array<int, kMaxPlayers> stack_gain{};
        stack_gain.fill(0);
        int distributed = 0;

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

        for (size_t ti = 0; ti < side_pots.size(); ++ti)
        {
            const int level = side_pots[ti].contribution_threshold;
            const int side_pot = side_pots[ti].amount;
            if (side_pot <= 0)
                continue;

            /// Table stakes: only seats with total hand contribution ≥ this pot’s threshold may win it.
            /// If every such seat folded, award among remaining contenders (orphan side pot).
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

            const QString msg = format_showdown_payout_lines_from_gains(stack_gain, n);
            const int banner_seat = banner_seat_from_showdown_gains(stack_gain, n);
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
    std::array<int, kMaxPlayers> gain{};
    gain.fill(0);
    for (int i = 0; i < nw; ++i)
    {
        const int seat = winners[static_cast<size_t>(i)];
        const int add = share + (i < rem ? 1 : 0);
        table[static_cast<size_t>(seat)].stack += add;
        gain[static_cast<size_t>(seat)] = add;
    }

    const QString msg = format_showdown_payout_lines_from_gains(gain, n);
    const int banner_seat = banner_seat_from_showdown_gains(gain, n);

    pot = 0;
    emit pot_changed();

    set_hand_result_status(msg, result_banner_card_assets_for_seat(banner_seat));
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
    if (!in_progress)
    {
        /// Wallet / buy-in targets may leave stacks at 0 until applied; `count_active()` requires stacks.
        seat_mgr_.flush_pending_bankroll_totals();
        seat_mgr_.apply_seat_buy_ins_to_table(false);
    }
    const int n = players_count();
    for (int i = 0; i < n; ++i)
        in_hand_[static_cast<size_t>(i)] = table[static_cast<size_t>(i)].stack > 0;
    if (human_sitting_out_)
        in_hand_[static_cast<size_t>(kHumanSeat)] = false;
    for (int s = 1; s < n; ++s)
    {
        if (!seat_mgr_.seat_participating_[static_cast<size_t>(s)])
            in_hand_[static_cast<size_t>(s)] = false;
    }

    if (count_active() < 2)
    {
        clear_for_new_hand();
        in_progress = false;
        seat_mgr_.try_auto_rebuys_for_busted_bots();
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
    if (seat_mgr_.pending_seat_buyins_apply_ && !in_progress)
    {
        seat_mgr_.apply_seat_buy_ins_to_table();
        seat_mgr_.pending_seat_buyins_apply_ = false;
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
    sb_seat_ = -1;
    bb_seat_ = -1;
    preflop_blind_level_ = 0;
    human_decision_ctrl_->reset();
    cards_dealt_ = false;
    ++hand_seq_;
    emit pot_changed();
}

int game::maxBuyInChips() const
{
    return seat_mgr_.maxBuyInChips();
}

int game::seatBankrollTotal(int seat) const
{
    return seat_mgr_.seatBankrollTotal(seat);
}

bool game::pendingSeatBankrollApply() const
{
    return seat_mgr_.pendingSeatBankrollApply();
}

int game::seatBuyIn(int seat) const
{
    return effectiveSeatBuyInChips(seat);
}

void game::setSeatBuyIn(int seat, int chips)
{
    if (seat >= 1)
    {
        const int bb = std::max(1, big_blind);
        const int cap = maxBuyInChips();
        const int c = std::clamp(chips, 1, cap);
        seat_cfg_[static_cast<size_t>(seat)].params.buy_in_bb = std::max(1, (c + bb - 1) / bb);
        seat_cfg_[static_cast<size_t>(seat)].params = clamp_bot_params(seat_cfg_[static_cast<size_t>(seat)].params);
        const int target = std::min(cap, std::max(1, seat_cfg_[static_cast<size_t>(seat)].params.buy_in_bb) * bb);
        seat_mgr_.setSeatBuyIn(seat, target);
    }
    else
        seat_mgr_.setSeatBuyIn(seat, chips);
}

void game::applySeatBuyInsToStacks()
{
    seat_mgr_.applySeatBuyInsToStacks();
}

void game::configure(int sb, int bb, int streetBet, int startStack)
{
    configureImpl(sb, bb, streetBet, startStack, true);
}

int game::effectiveSeatBuyInChips(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return starting_stack_;
    const int cap = maxBuyInChips();
    const size_t si = static_cast<size_t>(seat);
    const bool use_strategy_buy_in = (seat != kHumanSeat) || !interactive_human_;
    if (!use_strategy_buy_in)
        return std::clamp(seat_mgr_.seat_buy_in_[si], 0, cap);
    const int bb = std::max(1, big_blind);
    const int mult = std::max(1, seat_cfg_[si].params.buy_in_bb);
    return std::max(1, std::min(mult * bb, cap));
}

void game::setMaxOnTableBb(int maxBb)
{
    max_on_table_bb_ = std::clamp(maxBb, 1, 10000);
    if (!suppress_persist_)
        savePersistedSettings();
}

void game::configureImpl(int sb, int bb, int streetBet, int startStack, bool resetBankrollOnStackApply)
{
    small_blind = sb;
    big_blind = bb;
    street_bet_ = streetBet;
    const int cap = seat_mgr_.maxBuyInChips();
    starting_stack_ = std::max(1, std::min(startStack, cap));
    const int bbm = std::max(1, big_blind);
    const int max_bb_mul = std::max(1, cap / bbm);
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        const size_t szi = static_cast<size_t>(i);
        if (i == kHumanSeat && interactive_human_)
        {
            /// Align human buy-in with configured start stack (seat targets start at 0 before first configure).
            seat_mgr_.seat_buy_in_[szi] = std::clamp(starting_stack_, 0, cap);
            continue;
        }
        seat_cfg_[szi].params.buy_in_bb =
            std::min(std::max(1, seat_cfg_[szi].params.buy_in_bb), max_bb_mul);
        seat_cfg_[szi].params = clamp_bot_params(seat_cfg_[szi].params);
        seat_mgr_.seat_buy_in_[szi] = effectiveSeatBuyInChips(i);
    }
    seat_mgr_.apply_seat_buy_ins_to_table(resetBankrollOnStackApply);
    if (m_root)
    {
        m_root->setProperty("smallBlind", small_blind);
        m_root->setProperty("bigBlind", big_blind);
    }
    if (!suppress_persist_)
        savePersistedSettings();
}


int game::seatStrategyIndex(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return 0;
    return static_cast<int>(seat_cfg_[static_cast<size_t>(seat)].strategy);
}

void game::loadPersistedSettings()
{
    persistence_->loadPersistedSettings();
}

void game::savePersistedSettings() const
{
    persistence_->savePersistedSettings();
}

void game::seedMissingPersistedSettings() const
{
    persistence_->seedMissingPersistedSettings();
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
    if (seat != kHumanSeat || !interactive_human_)
        seat_mgr_.seat_buy_in_[si] = effectiveSeatBuyInChips(seat);
    ++range_revision_;
    emit rangeRevisionChanged();
    if (!suppress_persist_)
        savePersistedSettings();
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
    m[QStringLiteral("buyInBb")] = p.buy_in_bb;
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
    if (map.contains(QStringLiteral("buyInBb")))
        p.buy_in_bb = map.value(QStringLiteral("buyInBb")).toInt();
    p = clamp_bot_params(p);
    seat_cfg_[static_cast<size_t>(seat)].params = p;
    if (seat != kHumanSeat || !interactive_human_)
        seat_mgr_.seat_buy_in_[static_cast<size_t>(seat)] = effectiveSeatBuyInChips(seat);
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

QStringList game::strategyDisplayNames() const
{
    QStringList out;
    const int n = static_cast<int>(BotStrategy::Count);
    out.reserve(n);
    for (int i = 0; i < n; ++i)
        out.append(QString::fromUtf8(bot_strategy_name(static_cast<BotStrategy>(i))));
    return out;
}

bool game::applySeatRangeText(int seat, const QString &text, int layer)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return false;
    if (layer < 0 || layer > 2)
        return false;
    const bool ok = layer_matrix(seat_cfg_[static_cast<size_t>(seat)], layer)
        ->parse_text(text.toStdString());
    if (ok) {
        ++range_revision_;
        emit rangeRevisionChanged();
    }
    return ok;
}

void game::setRangeCell(int seat, int row, int col, double w, int layer)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    layer_matrix(seat_cfg_[static_cast<size_t>(seat)], layer)->set_cell(row, col, w);
    ++range_revision_;
    emit rangeRevisionChanged();
    if (!suppress_persist_)
        savePersistedSettings();
}

void game::resetSeatRangeFull(int seat)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    SeatBot &sb = seat_cfg_[static_cast<size_t>(seat)];
    sb.range_call.fill(1.0);
    sb.range_raise.fill(1.0);
    sb.range_bet.fill(1.0);
    ++range_revision_;
    emit rangeRevisionChanged();
    if (!suppress_persist_)
        savePersistedSettings();
}

void game::setSeatParticipating(int seat, bool participating)
{
    if (seat < 1 || seat >= kMaxPlayers)
        return;
    if (seat_mgr_.seatParticipating(seat) == participating)
        return;
    seat_mgr_.setSeatParticipating(seat, participating);
    if (!participating)
    {
        if (!in_progress || !in_hand_[static_cast<size_t>(seat)])
            seat_mgr_.cash_out_seat_off_table(seat);
        else
            seat_mgr_.mark_pending_cash_out_after_hand(seat);
    }
    else
    {
        /// Do not move wallet→stack here — `apply_seat_buy_ins_to_table` / `start()` already materialize
        /// buy-ins (including partial wallet). Eager `apply_buy_back_in` duplicated full-buy logic and
        /// skipped seats when wallet was short of the full target.
        /// Idle table: if at least one other player can deal, queue a hand (deferred so the Setup toggle
        /// returns immediately — `start()` runs the full hand on the same thread). In progress: unchanged;
        /// the bot is dealt in on the next hand via normal `in_hand_` / auto-deal.
        if (!suppress_persist_ && m_root && !in_progress
            && count_eligible_players_for_deal_after_apply() >= 2)
        {
            QTimer::singleShot(0, this, [this]() {
                if (!m_root || in_progress)
                    return;
                if (count_eligible_players_for_deal_after_apply() < 2)
                    return;
                beginNewHand();
            });
        }
    }
    notifySessionStatsChanged();
    if (!suppress_persist_)
        savePersistedSettings();
    flush_ui();
}

bool game::seatParticipating(int seat) const
{
    return seat_mgr_.seatParticipating(seat);
}

void game::setBotSlowActions(bool enabled)
{
    if (bot_slow_actions_ == enabled)
        return;
    bot_slow_actions_ = enabled;
    emit botSlowActionsChanged();
    if (persist_loaded_ && !suppress_persist_)
        savePersistedSettings();
}

bool game::botSlowActions() const
{
    return bot_slow_actions_;
}

void game::setWinningHandShowMs(int ms)
{
    const int v = std::clamp(ms, 500, 60000);
    if (winning_hand_show_ms_ == v)
        return;
    winning_hand_show_ms_ = v;
    emit winningHandShowMsChanged();
    if (persist_loaded_ && !suppress_persist_)
        savePersistedSettings();
}

int game::winningHandShowMs() const
{
    return winning_hand_show_ms_;
}

void game::setBotDecisionDelaySec(int sec)
{
    const int v = std::clamp(sec, 1, 30);
    if (bot_decision_delay_sec_ == v)
        return;
    bot_decision_delay_sec_ = v;
    emit botDecisionDelaySecChanged();
    if (persist_loaded_ && !suppress_persist_)
        savePersistedSettings();
}

int game::botDecisionDelaySec() const
{
    return bot_decision_delay_sec_;
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
    bankroll_tracker_.notifySessionStatsChanged();
}

void game::complete_hand_idle()
{
    seat_mgr_.flush_pending_cash_outs_after_hand();
    seat_mgr_.try_auto_rebuys_for_busted_bots();
    seat_mgr_.flush_pending_bankroll_totals();
    /// Normalize persisted buy-in vs wallet from stacks *before* snapshot so history and `v1/seat*/buyIn`
    /// match chips won at the table (see `SeatManager::sync_seat_buy_in_from_table_when_wallet_empty`).
    seat_mgr_.sync_seat_buy_in_from_table_when_wallet_empty();
    bankroll_tracker_.record_bankroll_snapshot();
    savePersistedSettings();
    flush_ui();
    schedule_next_hand_if_idle();
}

int game::seatWallet(int seat) const
{
    return seat_mgr_.seatWallet(seat);
}

int game::autoplayBuyInChips() const
{
    const int cap = maxBuyInChips();
    const int bb = std::max(1, big_blind);
    const int mult = std::max(1, seat_cfg_[static_cast<size_t>(kHumanSeat)].params.buy_in_bb);
    return std::max(1, std::min(mult * bb, cap));
}

bool game::canBuyBackIn(int seat) const
{
    if (seat == kHumanSeat && !interactive_human_)
        return false;
    return seat_mgr_.canBuyBackIn(seat);
}

bool game::tryBuyBackIn(int seat)
{
    if (seat == kHumanSeat && !interactive_human_)
        return false;
    return seat_mgr_.tryBuyBackIn(seat);
}

QVariantList game::seatRankings() const
{
    return bankroll_tracker_.seatRankings();
}

QVariantList game::bankrollSeries(int seat) const
{
    return bankroll_tracker_.bankrollSeries(seat);
}

QVariantList game::tableStackSeries(int seat) const
{
    return bankroll_tracker_.tableStackSeries(seat);
}

int game::bankrollSnapshotCount() const
{
    return bankroll_tracker_.bankrollSnapshotCount();
}

QVariantList game::bankrollSnapshotTimesMs() const
{
    return bankroll_tracker_.bankrollSnapshotTimesMs();
}

void game::applyPendingBankrollTotals()
{
    seat_mgr_.applyPendingBankrollTotals();
}

void game::setSeatBankrollTotal(int seat, int totalChips)
{
    seat_mgr_.setSeatBankrollTotal(seat, totalChips);
}

int game::sessionBaselineStack(int seat) const
{
    return bankroll_tracker_.sessionBaselineStack(seat);
}

int game::sessionBaselineTableStack(int seat) const
{
    return bankroll_tracker_.sessionBaselineTableStack(seat);
}

void game::resetBankrollSession()
{
    bankroll_tracker_.resetBankrollSession();
    if (persist_loaded_ && !suppress_persist_)
        savePersistedSettings();
    flush_ui();
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
    m.insert(QStringLiteral("preflopBlindLevel"), preflop_blind_level_);
    return m;
}

game::game(QObject *parent)
    : QObject(parent)
    , seat_mgr_(*this)
    , bankroll_tracker_(*this, this)
{
    for (int s = 0; s < kMaxPlayers; ++s)
    {
        player p;
        p.stack = 0;
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
    connect(&bankroll_tracker_, &BankrollTracker::sessionStatsChanged,
            this, &game::sessionStatsChanged);

    bankroll_tracker_.init_bankroll_after_configure();
    human_decision_ctrl_ = std::make_unique<HumanDecisionController>(*this, this);
    persistence_ = std::make_unique<GamePersistence>(*this);
}

game::~game() = default;

void game::buttonClicked(QString button)
{
    if (!m_root)
        return;
    if (button == QStringLiteral("MORE_TIME"))
    {
        human_decision_ctrl_->requestMoreTime();
        return;
    }
    if (human_decision_ctrl_->isWaitingForHumanBbPreflop())
    {
        if (button == QStringLiteral("CHECK"))
            human_decision_ctrl_->submitBbPreflopRaise(0);
        return;
    }
    if (human_decision_ctrl_->isWaitingForHumanCheck())
    {
        if (button == QStringLiteral("CHECK"))
            human_decision_ctrl_->submitCheckOrBet(true, 0);
        else if (button == QStringLiteral("FOLD"))
            human_decision_ctrl_->submitFoldFromCheck();
        return;
    }
    if (human_decision_ctrl_->isWaitingForHuman())
    {
        if (button == QStringLiteral("FOLD"))
            human_decision_ctrl_->submitFacingAction(0, 0);
        else if (button == QStringLiteral("CALL"))
            human_decision_ctrl_->submitFacingAction(1, 0);
        return;
    }
    if (button == QStringLiteral("CALL") || button == QStringLiteral("RAISE"))
        return;
    if (button == QStringLiteral("FOLD"))
        return;
}
