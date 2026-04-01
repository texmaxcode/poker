#ifndef POKER_BOT_H
#define POKER_BOT_H

#include <random>

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

#endif
