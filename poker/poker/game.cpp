#include "game.hpp"

#include "hand_eval.hpp"
#include "utils.hpp"

#include <algorithm>
#include <cmath>

#include <QCoreApplication>
#include <QEventLoop>
#include <QString>
#include <QThread>
#include <QTimer>

namespace {

int next_player_idx(int button, int offset, int player_count)
{
    if (player_count <= 0)
        return 0;
    return (button + offset) % player_count;
}

QString rank_to_asset(Rank r)
{
    switch (r)
    {
    case Rank::TWO:
        return QStringLiteral("2");
    case Rank::THREE:
        return QStringLiteral("3");
    case Rank::FOUR:
        return QStringLiteral("4");
    case Rank::FIVE:
        return QStringLiteral("5");
    case Rank::SIX:
        return QStringLiteral("6");
    case Rank::SEVEN:
        return QStringLiteral("7");
    case Rank::EIGHT:
        return QStringLiteral("8");
    case Rank::NINE:
        return QStringLiteral("9");
    case Rank::TEN:
        return QStringLiteral("10");
    case Rank::JACK:
        return QStringLiteral("jack");
    case Rank::QUEEN:
        return QStringLiteral("queen");
    case Rank::KING:
        return QStringLiteral("king");
    case Rank::ACE:
        return QStringLiteral("ace");
    }
    return QStringLiteral("2");
}

QString suite_to_asset(Suite s)
{
    switch (as_integer(s))
    {
    case 1:
        return QStringLiteral("clubs");
    case 2:
        return QStringLiteral("spades");
    case 3:
        return QStringLiteral("hearts");
    case 4:
        return QStringLiteral("diamonds");
    default:
        return QStringLiteral("clubs");
    }
}

QString card_to_asset(const card &c)
{
    return suite_to_asset(c.suite) + QLatin1Char('_') + rank_to_asset(c.rank) + QStringLiteral(".svg");
}

int min_raise_increment(int big_blind, int last_raise_inc, int street_bet)
{
    (void)street_bet;
    return std::max(big_blind, last_raise_inc);
}

bool bot_wants_raise_after_continue(BotStrategy s, double metric01, std::mt19937 &rng)
{
    if (s == BotStrategy::AlwaysCall)
        return false;
    std::uniform_real_distribution<double> u(0.0, 1.0);
    const double m = std::clamp(metric01, 0.0, 1.0);
    double p = 0.08 + 0.35 * m;
    if (s == BotStrategy::Maniac || s == BotStrategy::LooseAggressive)
        p += 0.18;
    if (s == BotStrategy::Nit || s == BotStrategy::Rock)
        p *= 0.35;
    return u(rng) < std::clamp(p, 0.0, 0.55);
}

bool bot_wants_open_bet_postflop(BotStrategy s, double hand_strength01, std::mt19937 &rng)
{
    if (s == BotStrategy::AlwaysCall)
        return false;
    std::uniform_real_distribution<double> u(0.0, 1.0);
    const double h = std::clamp(hand_strength01, 0.0, 1.0);
    double p = 0.06 + 0.45 * h;
    if (s == BotStrategy::Maniac || s == BotStrategy::LooseAggressive)
        p += 0.2;
    if (s == BotStrategy::Nit || s == BotStrategy::Rock)
        p *= 0.4;
    return u(rng) < std::clamp(p, 0.0, 0.65);
}

constexpr int kDecisionSeconds = 20;
constexpr int kMoreTimeExtraSeconds = 20;
constexpr int kMaxDecisionSecondsCap = 120;

bool bot_bb_check_or_raise(BotStrategy s, double range_weight, std::mt19937 &rng)
{
    if (s == BotStrategy::AlwaysCall)
        return false;
    std::uniform_real_distribution<double> u(0.0, 1.0);
    const double w = std::clamp(range_weight, 0.0, 1.0);
    double p = 0.12 + 0.4 * w;
    if (s == BotStrategy::Maniac || s == BotStrategy::LooseAggressive)
        p += 0.22;
    if (s == BotStrategy::Nit || s == BotStrategy::Rock)
        p *= 0.3;
    return u(rng) < std::clamp(p, 0.0, 0.7);
}

} // namespace

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

void game::collect_blinds()
{
    const int n = players_count();
    if (n < 2)
        return;
    const int sb = next_player_idx(button, 1, n);
    const int bb = next_player_idx(button, 2, n);
    pot += table[static_cast<size_t>(sb)].pay(small_blind);
    pot += table[static_cast<size_t>(bb)].pay(big_blind);
    emit pot_changed();
}

void game::take_bets()
{
    const int n = players_count();
    if (n < 2)
        return;
    for (int i = 0; i < n; ++i)
        pot += table[static_cast<size_t>(i)].take_from_stack(street_bet_);
    emit pot_changed();
}

void game::deal_hold_cards()
{
    const int n = players_count();
    if (n < 2)
        return;
    const int sb = next_player_idx(button, 1, n);
    for (int round = 0; round < 2; ++round)
    {
        for (int k = 0; k < n; ++k)
        {
            const int seat = (sb + k) % n;
            const card c = deck.get_card();
            if (round == 0)
                table[static_cast<size_t>(seat)].first_card = c;
            else
                table[static_cast<size_t>(seat)].second_card = c;
        }
    }
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

std::vector<int> game::action_order(Street st) const
{
    const int n = players_count();
    std::vector<int> order;
    if (n < 2)
        return order;

    int start = 0;
    if (st == Street::PRE_FLOP)
        start = next_player_idx(button, 3, n);
    else
        start = next_player_idx(button, 1, n);

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
    const int n = players_count();
    street_contrib_.fill(0);
    const int sb = next_player_idx(button, 1, n);
    const int bb = next_player_idx(button, 2, n);
    street_contrib_[static_cast<size_t>(sb)] = small_blind;
    street_contrib_[static_cast<size_t>(bb)] = big_blind;
    last_raise_increment_ = big_blind;
    bb_preflop_option_open_ = true;
}

void game::reset_postflop_street_contrib()
{
    const int n = players_count();
    for (int i = 0; i < n; ++i)
    {
        if (in_hand_[static_cast<size_t>(i)])
            street_contrib_[static_cast<size_t>(i)] = 0;
    }
    last_raise_increment_ = big_blind;
}

bool game::wait_for_human_need(int need_chips, Street st)
{
    (void)need_chips;
    (void)st;

    if (!m_root)
        return true;

    pending_human_need_ = need_chips;
    waiting_for_human_ = true;
    human_wanted_call_ = false;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

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
    QObject::connect(&human_decision_deadline_, &QTimer::timeout, this, [this]() {
        finish_human_decision(true);
    });

    human_decision_tick_.start();
    human_decision_deadline_.start();
    sync_ui();

    QEventLoop loop;
    QMetaObject::Connection conn = connect(this, &game::humanDecisionFinished, &loop, &QEventLoop::quit);
    loop.exec();
    QObject::disconnect(conn);

    human_decision_tick_.stop();
    human_decision_deadline_.stop();

    return human_wanted_call_;
}

void game::finish_human_decision(bool call_not_fold)
{
    if (!waiting_for_human_)
        return;
    waiting_for_human_ = false;
    human_wanted_call_ = call_not_fold;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    emit humanDecisionFinished();
}

bool game::wait_for_human_check_or_bet(Street st)
{
    (void)st;
    if (!m_root)
        return false;

    waiting_for_human_check_ = true;
    human_opened_bet_from_check_ = false;
    human_more_time_available_ = true;
    decision_seconds_left_ = kDecisionSeconds;

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
    QObject::connect(&human_decision_deadline_, &QTimer::timeout, this, [this]() {
        finish_human_check(false);
    });

    acting_seat_ = kHumanSeat;
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

void game::finish_human_check(bool open_bet)
{
    if (!waiting_for_human_check_)
        return;
    waiting_for_human_check_ = false;
    human_opened_bet_from_check_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    if (open_bet && table[static_cast<size_t>(kHumanSeat)].stack >= street_bet_)
    {
        pot += table[static_cast<size_t>(kHumanSeat)].take_from_stack(street_bet_);
        street_contrib_[static_cast<size_t>(kHumanSeat)] += street_bet_;
        last_raise_increment_ = street_bet_;
        human_opened_bet_from_check_ = true;
        emit pot_changed();
    }
    emit humanCheckFinished();
}

void game::setInteractiveHuman(bool enabled)
{
    interactive_human_ = enabled;
}

void game::setAutoHandLoop(bool enabled)
{
    auto_hand_loop_ = enabled;
}

void game::requestMoreTime()
{
    if ((!waiting_for_human_ && !waiting_for_human_check_) || !m_root || !human_more_time_available_)
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

bool game::handle_forced_response(int seat, Street st, int current_max)
{
    const size_t si = static_cast<size_t>(seat);
    int need = current_max - street_contrib_[si];
    if (need <= 0)
        return true;

    const int inc = min_raise_increment(big_blind, last_raise_increment_, street_bet_);

    if (seat == kHumanSeat)
    {
        if (table[si].stack < need)
        {
            in_hand_[si] = false;
            return true;
        }
        if (!interactive_human_ || !m_root)
        {
            pot += table[si].take_from_stack(need);
            street_contrib_[si] += need;
            emit pot_changed();
            return true;
        }

        acting_seat_ = seat;
        decision_seconds_left_ = kDecisionSeconds;
        flush_ui();

        const bool call = wait_for_human_need(need, st);
        acting_seat_ = -1;
        decision_seconds_left_ = 0;
        sync_ui();

        if (!call)
        {
            in_hand_[si] = false;
            return true;
        }

        pot += table[si].take_from_stack(need);
        street_contrib_[si] += need;
        emit pot_changed();
        return true;
    }

    acting_seat_ = seat;
    decision_seconds_left_ = 0;
    flush_ui();
    QThread::msleep(150);

    bool cont = false;
    double metric = 0.0;
    if (st == Street::PRE_FLOP)
    {
        metric = seat_cfg_[si].range.weight(table[si].first_card, table[si].second_card);
        cont = bot_preflop_continue(seat_cfg_[si].strategy, metric, rng_);
    }
    else
    {
        const auto cards = cards_for_strength(seat, st);
        metric = hand_strength_01_cards(cards);
        cont = bot_postflop_continue(seat_cfg_[si].strategy, metric, rng_);
    }

    if (!cont)
    {
        in_hand_[si] = false;
        acting_seat_ = -1;
        sync_ui();
        return true;
    }

    const bool try_raise = bot_wants_raise_after_continue(seat_cfg_[si].strategy, metric, rng_);
    const int new_max = current_max + inc;
    const int chips_for_raise = new_max - static_cast<int>(street_contrib_[si]);

    if (try_raise && table[si].stack >= chips_for_raise && chips_for_raise > need)
    {
        pot += table[si].take_from_stack(chips_for_raise);
        street_contrib_[si] += chips_for_raise;
        last_raise_increment_ = new_max - current_max;
        if (new_max > big_blind)
            bb_preflop_option_open_ = false;
        emit pot_changed();
        acting_seat_ = -1;
        sync_ui();
        return true;
    }

    if (table[si].stack < need)
    {
        in_hand_[si] = false;
        acting_seat_ = -1;
        sync_ui();
        return true;
    }
    pot += table[si].take_from_stack(need);
    street_contrib_[si] += need;
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
        if (!bot_wants_open_bet_postflop(seat_cfg_[static_cast<size_t>(seat)].strategy, hs, rng_))
            continue;
        if (table[static_cast<size_t>(seat)].stack < street_bet_)
            continue;
        pot += table[static_cast<size_t>(seat)].take_from_stack(street_bet_);
        street_contrib_[static_cast<size_t>(seat)] += street_bet_;
        last_raise_increment_ = street_bet_;
        emit pot_changed();
        return true;
    }
    return false;
}

bool game::handle_bb_preflop_option()
{
    const int n = players_count();
    const int bb = next_player_idx(button, 2, n);
    bb_preflop_option_open_ = false;

    if (!in_hand_[static_cast<size_t>(bb)])
        return false;

    if (bb == kHumanSeat)
        return false;

    const size_t bi = static_cast<size_t>(bb);
    const double rw = seat_cfg_[bi].range.weight(table[bi].first_card, table[bi].second_card);
    const bool raise = bot_bb_check_or_raise(seat_cfg_[bi].strategy, rw, rng_);
    const int inc = min_raise_increment(big_blind, last_raise_increment_, street_bet_);
    const int max_c = max_street_contrib();
    if (raise && inc > 0 && table[bi].stack >= inc && max_c == big_blind)
    {
        pot += table[bi].take_from_stack(inc);
        street_contrib_[bi] += inc;
        last_raise_increment_ = inc;
        emit pot_changed();
        return true;
    }
    return false;
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

    QString msg = QStringLiteral("Seat %1 wins — others folded").arg(winner + 1);
    award_pot_to_seat(winner);
    if (m_root)
        m_root->setProperty("statusText", msg);
}

bool game::run_street_betting(Street st)
{
    const int n = players_count();
    if (n < 2)
        return false;

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
            if (need > 0)
            {
                first_behind = seat;
                break;
            }
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

    if (contenders.size() == 1)
    {
        const int s = contenders.front();
        table[static_cast<size_t>(s)].stack += pot;
        const QString msg = QStringLiteral("Seat %1 wins — %2")
                                .arg(s + 1)
                                .arg(QString::fromStdString(describe_hand_score(best_hand_score(get_hand_vector(s)))));
        pot = 0;
        emit pot_changed();
        if (m_root)
            m_root->setProperty("statusText", msg);
        return;
    }

    std::vector<int> winners = {contenders.front()};
    for (size_t w = 1; w < contenders.size(); ++w)
    {
        const int s = contenders[w];
        const int cmp = compare_holdem_hands(get_hand_vector(s), get_hand_vector(winners.front()));
        if (cmp > 0)
            winners = {s};
        else if (cmp == 0)
            winners.push_back(s);
    }

    const int nw = static_cast<int>(winners.size());
    const int share = pot / nw;
    const int rem = pot % nw;
    for (int i = 0; i < nw; ++i)
        table[static_cast<size_t>(winners[static_cast<size_t>(i)])].stack += share + (i < rem ? 1 : 0);

    QString msg;
    if (winners.size() == 1)
    {
        msg = QStringLiteral("Seat %1 wins — %2")
                  .arg(winners.front() + 1)
                  .arg(QString::fromStdString(describe_hand_score(best_hand_score(get_hand_vector(winners.front())))));
    }
    else
    {
        msg = QStringLiteral("Chop (%1 ways) — %2")
                  .arg(winners.size())
                  .arg(QString::fromStdString(describe_hand_score(best_hand_score(get_hand_vector(winners.front())))));
    }

    pot = 0;
    emit pot_changed();

    if (m_root)
        m_root->setProperty("statusText", msg);
}

void game::switch_button()
{
    if (players_count() > 0)
        button = (button + 1) % players_count();
}

void game::sync_ui()
{
    if (!m_root)
    {
        emit ui_state_changed();
        return;
    }

    m_root->setProperty("showdown", ui_showdown_);
    m_root->setProperty("pot", pot);
    m_root->setProperty("buttonSeat", button);
    m_root->setProperty("actingSeat", acting_seat_);
    m_root->setProperty("decisionSecondsLeft", decision_seconds_left_);
    m_root->setProperty("humanMoreTimeAvailable",
                        (waiting_for_human_ || waiting_for_human_check_) && human_more_time_available_);
    m_root->setProperty("humanCanCheck", waiting_for_human_check_);
    m_root->setProperty("smallBlind", small_blind);
    m_root->setProperty("bigBlind", big_blind);

    QVariantList stacks;
    QVariantList c1;
    QVariantList c2;
    QVariantList inHand;
    for (int i = 0; i < kMaxPlayers; ++i)
    {
        if (i < players_count())
        {
            stacks.append(table[static_cast<size_t>(i)].stack);
            c1.append(card_to_asset(table[static_cast<size_t>(i)].first_card));
            c2.append(card_to_asset(table[static_cast<size_t>(i)].second_card));
            inHand.append(in_hand_[static_cast<size_t>(i)]);
        }
        else
        {
            stacks.append(0);
            c1.append(QString());
            c2.append(QString());
            inHand.append(false);
        }
    }
    m_root->setProperty("seatStacks", stacks);
    m_root->setProperty("seatC1", c1);
    m_root->setProperty("seatC2", c2);
    m_root->setProperty("seatInHand", inHand);

    m_root->setProperty("board0", (street >= Street::FLOP && flop.size() > 0) ? card_to_asset(flop[0]) : QString());
    m_root->setProperty("board1", (street >= Street::FLOP && flop.size() > 1) ? card_to_asset(flop[1]) : QString());
    m_root->setProperty("board2", (street >= Street::FLOP && flop.size() > 2) ? card_to_asset(flop[2]) : QString());
    m_root->setProperty("board3", (street >= Street::TURN && flop.size() >= 3) ? card_to_asset(turn) : QString());
    m_root->setProperty("board4", (street >= Street::RIVER && flop.size() >= 3) ? card_to_asset(river) : QString());

    emit ui_state_changed();
}

void game::flush_ui()
{
    sync_ui();
    QCoreApplication::processEvents(QEventLoop::AllEvents, 100);
}

void game::start()
{
    const int n = players_count();
    for (int i = 0; i < n; ++i)
        in_hand_[static_cast<size_t>(i)] = true;

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
        schedule_next_hand_if_idle();
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
        schedule_next_hand_if_idle();
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
        schedule_next_hand_if_idle();
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
        schedule_next_hand_if_idle();
        return;
    }

    do_payouts();
    switch_button();
    in_progress = false;
    ui_showdown_ = true;
    flush_ui();
    schedule_next_hand_if_idle();
}

void game::beginNewHand()
{
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

void game::clear_for_new_hand()
{
    ui_showdown_ = false;
    pot = 0;
    flop.clear();
    deck = card_deck{};
    acting_seat_ = -1;
    decision_seconds_left_ = 0;
    waiting_for_human_ = false;
    waiting_for_human_check_ = false;
    human_decision_tick_.stop();
    human_decision_deadline_.stop();
    emit pot_changed();
}

void game::on_pot_changed()
{
    if (m_root)
        m_root->setProperty("pot", pot);
}

void game::configure(int sb, int bb, int streetBet, int startStack)
{
    small_blind = sb;
    big_blind = bb;
    street_bet_ = streetBet;
    starting_stack_ = startStack;
    for (auto &p : table)
        p.reset_stack(starting_stack_);
    if (m_root)
    {
        m_root->setProperty("smallBlind", small_blind);
        m_root->setProperty("bigBlind", big_blind);
    }
}

void game::setSeatStrategy(int seat, int strategyIndex)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    const int n = static_cast<int>(BotStrategy::Count);
    if (strategyIndex < 0 || strategyIndex >= n)
        return;
    seat_cfg_[static_cast<size_t>(seat)].strategy = static_cast<BotStrategy>(strategyIndex);
}

bool game::applySeatRangeText(int seat, const QString &text)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return false;
    return seat_cfg_[static_cast<size_t>(seat)].range.parse_text(text.toStdString());
}

void game::setRangeCell(int seat, int row, int col, double w)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    seat_cfg_[static_cast<size_t>(seat)].range.set_cell(row, col, w);
}

void game::resetSeatRangeFull(int seat)
{
    if (seat < 0 || seat >= kMaxPlayers)
        return;
    seat_cfg_[static_cast<size_t>(seat)].range.fill(1.0);
}

QVariantList game::getRangeGrid(int seat) const
{
    QVariantList list;
    if (seat < 0 || seat >= kMaxPlayers)
        return list;
    double buf[169];
    seat_cfg_[static_cast<size_t>(seat)].range.copy_to_flat(buf, 169);
    for (int i = 0; i < 169; ++i)
        list.append(buf[i]);
    return list;
}

QString game::exportSeatRangeText(int seat) const
{
    if (seat < 0 || seat >= kMaxPlayers)
        return {};
    return QString::fromStdString(seat_cfg_[static_cast<size_t>(seat)].range.export_text());
}

game::game(QObject *parent)
    : QObject(parent)
    , human_decision_tick_(this)
    , human_decision_deadline_(this)
{
    for (int s = 0; s < kMaxPlayers; ++s)
    {
        player p;
        p.stack = starting_stack_;
        p.first_card = card(Rank::TWO, Suite::CLUBS);
        p.second_card = card(Rank::THREE, Suite::CLUBS);
        join_table(p);
        seat_cfg_[static_cast<size_t>(s)].strategy = BotStrategy::AlwaysCall;
        seat_cfg_[static_cast<size_t>(s)].range.fill(1.0);
        in_hand_[static_cast<size_t>(s)] = true;
    }

    QObject::connect(this, &game::pot_changed, this, &game::on_pot_changed);
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
    if (waiting_for_human_check_)
    {
        if (button == QStringLiteral("CHECK"))
            finish_human_check(false);
        else if (button == QStringLiteral("RAISE"))
            finish_human_check(true);
        return;
    }
    if (waiting_for_human_)
    {
        if (button == QStringLiteral("CALL") || button == QStringLiteral("RAISE"))
            finish_human_decision(true);
        else if (button == QStringLiteral("FOLD"))
            finish_human_decision(false);
        return;
    }
    if (button == QStringLiteral("CALL") || button == QStringLiteral("RAISE"))
    {
        m_root->setProperty(
            "statusText",
            QStringLiteral("No bet to face right now."));
        return;
    }
    if (button == QStringLiteral("FOLD"))
        return;
}
