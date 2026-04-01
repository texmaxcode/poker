#ifndef POKER_BOT_H
#define POKER_BOT_H

#include <random>
#include <string>

class RangeMatrix;

enum class BotStrategy : int
{
    AlwaysCall = 0,
    Rock,
    Nit,
    TightAggressive,
    LoosePassive,
    LooseAggressive,
    Balanced,
    Maniac,
    Count
};

struct BotParams
{
    double preflop_exponent;
    double postflop_exponent;
};

BotParams params_for(BotStrategy s);

bool bot_preflop_continue(BotStrategy s, double range_weight, std::mt19937 &rng);
bool bot_postflop_continue(BotStrategy s, double hand_strength01, std::mt19937 &rng);

const char *bot_strategy_name(BotStrategy s);

/// Default 13×13 weights for this archetype (invoked when a seat’s bot type is chosen).
void fill_preset_range(RangeMatrix &m, BotStrategy s);

/// Multi-line description: tuning exponents, preset chart, and aggression profile.
std::string strategy_description(BotStrategy s);

#endif
