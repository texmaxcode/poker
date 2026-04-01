#include "bot.hpp"

#include <algorithm>
#include <cmath>
#include <random>

BotParams params_for(BotStrategy s)
{
    switch (s)
    {
    case BotStrategy::AlwaysCall:
        return {0.0, 0.0};
    case BotStrategy::Rock:
        return {3.2, 2.8};
    case BotStrategy::Nit:
        return {2.6, 2.4};
    case BotStrategy::TightAggressive:
        return {2.0, 0.85};
    case BotStrategy::LoosePassive:
        return {0.75, 1.8};
    case BotStrategy::LooseAggressive:
        return {0.55, 0.65};
    case BotStrategy::Balanced:
        return {1.15, 1.1};
    case BotStrategy::Maniac:
        return {0.35, 0.4};
    default:
        return {1.0, 1.0};
    }
}

bool bot_preflop_continue(BotStrategy s, double range_weight, std::mt19937 &rng)
{
    if (s == BotStrategy::AlwaysCall)
        return true;
    const auto p = params_for(s);
    const double w = std::clamp(range_weight, 0.0, 1.0);
    const double t = std::pow(w, p.preflop_exponent);
    std::uniform_real_distribution<double> u(0.0, 1.0);
    return u(rng) < t;
}

bool bot_postflop_continue(BotStrategy s, double hand_strength01, std::mt19937 &rng)
{
    if (s == BotStrategy::AlwaysCall)
        return true;
    const auto p = params_for(s);
    const double h = std::clamp(hand_strength01, 0.0, 1.0);
    const double t = std::pow(h, p.postflop_exponent);
    std::uniform_real_distribution<double> u(0.0, 1.0);
    return u(rng) < t;
}

const char *bot_strategy_name(BotStrategy s)
{
    switch (s)
    {
    case BotStrategy::AlwaysCall:
        return "Always call (test)";
    case BotStrategy::Rock:
        return "Rock";
    case BotStrategy::Nit:
        return "Nit";
    case BotStrategy::TightAggressive:
        return "Tight–aggressive";
    case BotStrategy::LoosePassive:
        return "Loose–passive";
    case BotStrategy::LooseAggressive:
        return "Loose–aggressive";
    case BotStrategy::Balanced:
        return "Balanced";
    case BotStrategy::Maniac:
        return "Maniac";
    default:
        return "?";
    }
}
