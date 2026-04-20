// Showdown and pot distribution (`game::do_payouts`) — split from `game.cpp` for readability and testing focus.

#include "game.hpp"

#include "hand_eval.hpp"
#include "holdem_side_pot.hpp"

#include <algorithm>
#include <array>
#include <vector>

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
