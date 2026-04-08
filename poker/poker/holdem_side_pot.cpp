#include "holdem_side_pot.hpp"

#include <algorithm>
#include <numeric>

bool nlhe_build_side_pot_slices(const std::vector<int> &hand_contribution_per_seat,
                                int total_pot_chips,
                                std::vector<NlheSidePotSlice> *slices_out)
{
    if (!slices_out)
        return false;
    slices_out->clear();

    const long sum = std::accumulate(hand_contribution_per_seat.begin(), hand_contribution_per_seat.end(), 0L);
    if (sum != static_cast<long>(total_pot_chips) || total_pot_chips <= 0)
        return false;

    std::vector<int> unique_levels;
    for (int c : hand_contribution_per_seat)
    {
        if (c > 0)
            unique_levels.push_back(c);
    }
    if (unique_levels.empty())
        return false;

    std::sort(unique_levels.begin(), unique_levels.end());
    unique_levels.erase(std::unique(unique_levels.begin(), unique_levels.end()), unique_levels.end());

    const int n = static_cast<int>(hand_contribution_per_seat.size());
    int prev = 0;
    int distributed = 0;
    for (int level : unique_levels)
    {
        const int increment = level - prev;
        if (increment < 0)
            return false;
        int n_cover = 0;
        for (int i = 0; i < n; ++i)
        {
            if (hand_contribution_per_seat[static_cast<size_t>(i)] >= level)
                ++n_cover;
        }
        const int slice_amount = increment * n_cover;
        if (slice_amount < 0)
            return false;
        NlheSidePotSlice slice;
        slice.amount = slice_amount;
        slice.contribution_threshold = level;
        slices_out->push_back(slice);
        distributed += slice_amount;
        prev = level;
    }

    if (distributed != total_pot_chips)
    {
        slices_out->clear();
        return false;
    }
    return true;
}

bool holdem_nlhe_side_pot_breakdown(const std::vector<int> &hand_contribution_per_seat,
                                    int total_pot_chips,
                                    std::vector<int> *sorted_unique_levels,
                                    std::vector<int> *tier_chips)
{
    if (!sorted_unique_levels || !tier_chips)
        return false;
    sorted_unique_levels->clear();
    tier_chips->clear();

    std::vector<NlheSidePotSlice> slices;
    if (!nlhe_build_side_pot_slices(hand_contribution_per_seat, total_pot_chips, &slices))
        return false;
    for (const NlheSidePotSlice &s : slices)
    {
        sorted_unique_levels->push_back(s.contribution_threshold);
        tier_chips->push_back(s.amount);
    }
    return true;
}
