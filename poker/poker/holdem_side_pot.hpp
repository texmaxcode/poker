#ifndef TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H
#define TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H

#include <vector>

/// NLHE side pots (same model as major play-money sites): take each seat’s **total** contribution
/// to this hand (all streets). Sort **unique** positive amounts ascending — each is a stack depth
/// (short stack first, then next all-in, …). Between consecutive depths `prev` and `L`, the pot is
/// `(L - prev) * (# seats whose contribution >= L)` (everyone still in for that layer pays the
/// slice). The first slice is the **main pot**; each further slice is **side pot 1, 2, …**
///
/// `hand_contribution_per_seat[i]` = total chips seat `i` put into this hand.
/// `total_pot_chips` must equal the sum of contributions.
///
/// On success, `sorted_unique_levels` has length `k >= 1` and `tier_chips` has the same length;
/// `tier_chips[0]` is the main pot, `tier_chips[1]` the first side pot, etc. Sums to `total_pot_chips`.
/// For a single contribution depth (`k == 1`), there is only one physical pot — callers treat
/// `k < 2` as “no side-pot breakdown” for HUD.
bool holdem_nlhe_side_pot_breakdown(const std::vector<int> &hand_contribution_per_seat,
                                    int total_pot_chips,
                                    std::vector<int> *sorted_unique_levels,
                                    std::vector<int> *tier_chips);

#endif // TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H
