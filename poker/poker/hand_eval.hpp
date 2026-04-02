#ifndef TEXAS_HOLDEM_GYM_HAND_EVAL_H
#define TEXAS_HOLDEM_GYM_HAND_EVAL_H

#include "cards.hpp"

#include <array>
#include <string>
#include <vector>

/// Best 5 of 7; lexicographically larger tuple = stronger hand.
/// Tuple: [category][...kickers]. Category 8 = straight flush ... 0 = high card.
std::array<int, 8> best_hand_score(const std::vector<card> &seven_cards);

/// Cards that realize the best Hold’em score from 2–7 known cards (holes + board). If fewer than five
/// cards are available (e.g. preflop), returns all of them. Order is sorted high rank first for display.
std::vector<card> best_five_cards_for_display(const std::vector<card> &cards);

/// >0 if hand_a wins, <0 if hand_b wins, 0 = chop.
int compare_holdem_hands(const std::vector<card> &seven_a, const std::vector<card> &seven_b);

std::string describe_hand_score(const std::array<int, 8> &score);

/// Best current 5-card holding from 2 (preflop holes) or 5–7 community cards.
std::string describe_holdem_hand(const std::vector<card> &cards);

/// Rough 0..1 strength for postflop bot heuristics (not equity).
double hand_strength_01(const std::vector<card> &seven_cards);

/// Same metric for 5–7 known cards (flop / turn / river).
double hand_strength_01_cards(const std::vector<card> &cards);

#endif // TEXAS_HOLDEM_GYM_HAND_EVAL_H
