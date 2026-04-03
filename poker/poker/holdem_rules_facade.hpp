#ifndef TEXAS_HOLDEM_GYM_HOLDEM_RULES_FACADE_H
#define TEXAS_HOLDEM_GYM_HOLDEM_RULES_FACADE_H

/// Thin namespaced aliases so call sites can refer to “modules” without renaming the core types.
/// The implementation lives in `hand_eval.*`, `holdem_side_pot.*`, `cards.*`, `player.*`, `game.*`.

#include "hand_eval.hpp"
#include "holdem_side_pot.hpp"

namespace Holdem {

namespace HandEvaluator {
using ::best_hand_score;
using ::best_five_cards_for_display;
using ::compare_holdem_hands;
using ::describe_hand_score;
using ::describe_holdem_hand;
} // namespace HandEvaluator

namespace SidePot {
using ::holdem_nlhe_side_pot_breakdown;
} // namespace SidePot

} // namespace Holdem

#endif // TEXAS_HOLDEM_GYM_HOLDEM_RULES_FACADE_H
