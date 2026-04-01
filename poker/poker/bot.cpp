#include "bot.hpp"

#include "range_matrix.hpp"

#include <algorithm>
#include <cmath>
#include <random>
#include <sstream>

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

void fill_preset_range(RangeMatrix &m, BotStrategy s)
{
    switch (s)
    {
    case BotStrategy::AlwaysCall:
        m.fill(1.0);
        return;
    case BotStrategy::Rock:
        if (!m.parse_text(
                "QQ+,AKs,AKo,AQs,AQo,KQs"))
            m.fill(1.0);
        return;
    case BotStrategy::Nit:
        if (!m.parse_text("JJ+,AKs,AKo,AQs"))
            m.fill(1.0);
        return;
    case BotStrategy::TightAggressive:
        if (!m.parse_text(
                "TT+,AKs,AKo,AQs,AQo,AJs,ATs,KQs,KJs,QJs,JTs,T9s,98s,87s"))
            m.fill(1.0);
        return;
    case BotStrategy::LoosePassive:
    case BotStrategy::LooseAggressive:
    case BotStrategy::Maniac:
        m.fill(1.0);
        return;
    case BotStrategy::Balanced:
        if (!m.parse_text(
                "99+,AKs,AKo,AQs,AQo,AJs,ATs,A9s,KQs,KJs,KTs,QJs,QTs,JTs,T9s,98s,87s,76s,65s"))
            m.fill(1.0);
        return;
    default:
        m.fill(1.0);
        return;
    }
}

std::string strategy_description(BotStrategy s)
{
    std::ostringstream o;
    o << bot_strategy_name(s) << "\n\n";

    const BotParams p = params_for(s);
    o << "Preflop tuning: exponent " << p.preflop_exponent << "\n";
    o << "  Each hole combo has a chart weight w in [0,1]. The bot continues preflop with "
         "probability w^exponent (after a random trial), so low-weight cells fold more often "
         "when the exponent is high.\n\n";

    o << "Postflop tuning: exponent " << p.postflop_exponent << "\n";
    o << "  Uses estimated hand strength h in [0,1]; continue chance is h^exponent. Higher "
         "exponent = more cautious with medium-strength hands.\n\n";

    o << "Default preset chart (1.0 = in range at full weight; 0 = folded out):\n";
    switch (s)
    {
    case BotStrategy::AlwaysCall:
        o << "  All 169 combos at weight 1.0 (test / always see flop if allowed).\n";
        break;
    case BotStrategy::Rock:
        o << "  QQ+, AKs, AKo, AQs, AQo, KQs\n";
        break;
    case BotStrategy::Nit:
        o << "  JJ+, AKs, AKo, AQs\n";
        break;
    case BotStrategy::TightAggressive:
        o << "  TT+, AKs, AKo, AQs, AQo, AJs, ATs, KQs, KJs, QJs, JTs, T9s, 98s, 87s\n";
        break;
    case BotStrategy::LoosePassive:
    case BotStrategy::LooseAggressive:
    case BotStrategy::Maniac:
        o << "  Full matrix at 1.0 — enters preflop with any two cards; style differs postflop "
             "and in aggression heuristics.\n";
        break;
    case BotStrategy::Balanced:
        o << "  99+, AKs, AKo, AQs, AQo, AJs, ATs, A9s, KQs, KJs, KTs, QJs, QTs, JTs, T9s, 98s, "
             "87s, 76s, 65s\n";
        break;
    default:
        o << "  (unspecified)\n";
        break;
    }

    o << "\nIn-engine aggression (postflop / raises):\n";
    switch (s)
    {
    case BotStrategy::AlwaysCall:
        o << "  No open raises or barrels; always calls when continuing.";
        break;
    case BotStrategy::Maniac:
    case BotStrategy::LooseAggressive:
        o << "  Raises and probe bets more often; BB check-raise more likely with playable weights.";
        break;
    case BotStrategy::Nit:
    case BotStrategy::Rock:
        o << "  Fewer semi-bluffs; smaller raise frequency; BB often checks without a strong hand.";
        break;
    case BotStrategy::TightAggressive:
    case BotStrategy::Balanced:
        o << "  Moderate bluff frequency; mixes between trapping and pressure.";
        break;
    case BotStrategy::LoosePassive:
        o << "  Wide preflop chart but less tendency to build the pot without strength.";
        break;
    default:
        o << "  Default aggression profile.";
        break;
    }
    o << "\n";

    return o.str();
}
