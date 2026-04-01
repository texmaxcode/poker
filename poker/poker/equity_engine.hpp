#ifndef POKER_EQUITY_ENGINE_H
#define POKER_EQUITY_ENGINE_H

#include "cards.hpp"
#include "range_matrix.hpp"

#include <random>
#include <string>
#include <vector>

struct EquityResult
{
    double equity_hero = 0; // 0..1
    double std_err = 0;     // approximate std dev of estimate
    int iterations_used = 0;
    std::string error;
};

/// Monte Carlo equity: hero hole cards vs villain range (rejection sampling on weights).
/// Board may contain 0–5 cards. Dead cards must include hero + board; villain is sampled excluding dead.
EquityResult monte_carlo_equity_vs_range(const card &hero1,
                                         const card &hero2,
                                         const std::vector<card> &board,
                                         const RangeMatrix &villain_range,
                                         int iterations,
                                         std::mt19937 &rng);

/// Hero vs specific villain hole cards (same runout rules).
EquityResult monte_carlo_equity_vs_hand(const card &hero1,
                                        const card &hero2,
                                        const std::vector<card> &board,
                                        const card &villain1,
                                        const card &villain2,
                                        int iterations,
                                        std::mt19937 &rng);

bool parse_card_string(const std::string &tok, card &out);
bool parse_board_string(const std::string &line, std::vector<card> &out, std::string &err);

#endif
