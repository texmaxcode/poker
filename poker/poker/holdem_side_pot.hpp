#ifndef TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H
#define TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H

#include <vector>

/// NLHE side-pot decomposition from **per-seat total contributions this hand** (all streets).
///
/// Algorithm (standard cash-game model):
/// - Take **unique positive** contribution amounts, sorted ascending: L₁ < L₂ < … < Lₖ.
/// - Between depths `prev` and `Lⱼ`, each seat with **total contribution ≥ Lⱼ** puts `(Lⱼ − prev)` into
///   that slice. Slice size = `(Lⱼ − prev) × |{ i : contrib[i] ≥ Lⱼ }|`.
/// - Sums of all slices equal `sum(contrib)` (must match `total_pot_chips`).
///
/// **Showdown eligibility** (handled in `game::do_payouts`, not here): a live player wins slice `j`
/// only if `contrib[seat] ≥ Lⱼ`. If every seat with `contrib ≥ Lⱼ` has **folded**, that slice is
/// still in the middle; callers award it to the best hand among **remaining** contenders (orphan
/// side pot).
///
/// Output: `sorted_unique_levels` = distinct contribution cutoffs (smallest … largest).
/// `tier_chips` = chip count for **main pot** (`[0]`) then **side pot 1** (`[1]`), **side pot 2** (`[2]`), …
/// (same breakdown as on Global Poker / other NL sites; the name “tier” is historical).
bool holdem_nlhe_side_pot_breakdown(const std::vector<int> &hand_contribution_per_seat,
                                    int total_pot_chips,
                                    std::vector<int> *sorted_unique_levels,
                                    std::vector<int> *tier_chips);

#endif // TEXAS_HOLDEM_GYM_HOLDEM_SIDE_POT_H
