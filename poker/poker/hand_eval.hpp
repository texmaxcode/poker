#ifndef POKER_HAND_EVAL_H
#define POKER_HAND_EVAL_H

#include "cards.hpp"

#include <array>
#include <string>
#include <vector>

/// Best 5 of 7; lexicographically larger tuple = stronger hand.
/// Tuple: [category][...kickers]. Category 8 = straight flush ... 0 = high card.
std::array<int, 8> best_hand_score(const std::vector<card> &seven_cards);

/// >0 if hand_a wins, <0 if hand_b wins, 0 = chop.
int compare_holdem_hands(const std::vector<card> &seven_a, const std::vector<card> &seven_b);

std::string describe_hand_score(const std::array<int, 8> &score);

/// Rough 0..1 strength for postflop bot heuristics (not equity).
double hand_strength_01(const std::vector<card> &seven_cards);

/// Same metric for 5–7 known cards (flop / turn / river).
double hand_strength_01_cards(const std::vector<card> &cards);

#endif
