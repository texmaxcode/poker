#ifndef TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H
#define TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H

#include <vector>

/// NLHE **table-stakes** side pots from per-seat **total chips committed this hand** (all streets).
/// Matches cash-game rules used on Global Poker and similar sites: you only win pots you funded;
/// deeper stacks create **main pot** + **side pot 1, 2, …** from contribution thresholds.
///
/// **Build algorithm** (equivalent to sorting unique contribution levels ascending):
/// - Let L₁ < L₂ < … < Lₖ be the distinct positive values in `contrib`.
/// - For each j, slice j has size `(Lⱼ − Lⱼ₋₁) × |{ seats : contrib[seat] ≥ Lⱼ }|` with L₀ = 0.
/// - That is the **main pot** (j = 1) and **side pots** thereafter. Sum of slices = sum(contrib) = pot.
///
/// **Showdown**: seat `s` may win slice j iff `contrib[s] ≥ Lⱼ` and they are still in the showdown
/// (folded players forfeit winning but their chips stay in the pot — resolved in `game::do_payouts`).

struct NlheSidePotSlice
{
    /// Chips in this physical pot (main or a side pot).
    int amount = 0;
    /// Minimum total **hand** contribution required to **win** this pot among live players.
    int contribution_threshold = 0;
};

/// Two-player **effective stack** (for all-in / side-pot intuition): min of the two stacks.
inline int nlhe_effective_stack_chips(int stack_a, int stack_b)
{
    return stack_a < stack_b ? stack_a : stack_b;
}

/// Build ordered list: `[0]` = main pot, `[1]` = first side pot, …
/// Fails if `contrib` sizes don’t sum to `total_pot_chips` or inputs are invalid.
bool nlhe_build_side_pot_slices(const std::vector<int> &hand_contribution_per_seat,
                                int total_pot_chips,
                                std::vector<NlheSidePotSlice> *slices_out);

/// Legacy helper for tests / callers that want parallel `levels` + `tier_chips` arrays.
/// `sorted_unique_levels[j]` = Lⱼ, `tier_chips[j]` = slice chip count (main, side 1, …).
bool holdem_nlhe_side_pot_breakdown(const std::vector<int> &hand_contribution_per_seat,
                                    int total_pot_chips,
                                    std::vector<int> *sorted_unique_levels,
                                    std::vector<int> *tier_chips);

#endif // TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H
