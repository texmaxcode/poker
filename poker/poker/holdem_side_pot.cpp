#include "holdem_side_pot.hpp"

#include <algorithm>
#include <numeric>

bool holdem_nlhe_side_pot_breakdown(const std::vector<int> &hand_contribution_per_seat,
                                    int total_pot_chips,
                                    std::vector<int> *sorted_unique_levels,
                                    std::vector<int> *tier_chips)
{
    if (!sorted_unique_levels || !tier_chips)
        return false;
    sorted_unique_levels->clear();
    tier_chips->clear();

    const long sum =
        std::accumulate(hand_contribution_per_seat.begin(), hand_contribution_per_seat.end(), 0L);
    if (sum != static_cast<long>(total_pot_chips) || total_pot_chips <= 0)
        return false;

    std::vector<int> levels;
    for (int c : hand_contribution_per_seat)
    {
        if (c > 0)
            levels.push_back(c);
    }
    if (levels.empty())
        return false;

    std::sort(levels.begin(), levels.end());
    levels.erase(std::unique(levels.begin(), levels.end()), levels.end());

    const int n = static_cast<int>(hand_contribution_per_seat.size());
    int distributed = 0;
    int prev = 0;
    for (int level : levels)
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
        const int slice = increment * n_cover;
        if (slice < 0)
            return false;
        tier_chips->push_back(slice);
        distributed += slice;
        prev = level;
    }

    if (distributed != total_pot_chips)
        return false;

    *sorted_unique_levels = std::move(levels);
    return true;
}
