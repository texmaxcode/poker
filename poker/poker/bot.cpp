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
        return {0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 100};
    case BotStrategy::Rock:
        return {3.2, 2.8, 0.0, 0.35, 0.0, 0.4, 0.0, 0.3, 100};
    case BotStrategy::Nit:
        return {2.6, 2.4, 0.0, 0.35, 0.0, 0.4, 0.0, 0.3, 100};
    case BotStrategy::TightAggressive:
        return {2.0, 0.85, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 100};
    case BotStrategy::LoosePassive:
        return {0.75, 1.8, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 100};
    case BotStrategy::LooseAggressive:
        return {0.55, 0.65, 0.18, 1.0, 0.2, 1.0, 0.22, 1.0, 100};
    case BotStrategy::Balanced:
        return {1.15, 1.1, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 100};
    case BotStrategy::Maniac:
        return {0.35, 0.4, 0.18, 1.0, 0.2, 1.0, 0.22, 1.0, 100};
    case BotStrategy::GTOHeuristic:
        // Near-balanced frequencies with mild pressure — starting point; user can tune every field.
        return {1.12, 1.08, 0.09, 0.82, 0.10, 0.78, 0.11, 0.75, 100};
    default:
        return {1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 100};
    }
}

namespace {

bool bot_continue_trial(double exponent, double metric01, std::mt19937 &rng)
{
    const double m = std::clamp(metric01, 0.0, 1.0);
    const double exp = std::max(exponent, 1e-6);
    const double t = std::pow(m, exp);
    std::uniform_real_distribution<double> u(0.0, 1.0);
    return u(rng) < t;
}

} // namespace

bool bot_preflop_continue_p(const BotParams &p, double range_weight, std::mt19937 &rng)
{
    return bot_continue_trial(p.preflop_exponent, range_weight, rng);
}

bool bot_postflop_continue_p(const BotParams &p, double hand_strength01, std::mt19937 &rng)
{
    return bot_continue_trial(p.postflop_exponent, hand_strength01, rng);
}

bool bot_wants_raise_after_continue_p(const BotParams &p, double metric01, std::mt19937 &rng)
{
    std::uniform_real_distribution<double> u(0.0, 1.0);
    const double m = std::clamp(metric01, 0.0, 1.0);
    double prob = 0.08 + 0.35 * m;
    prob += p.facing_raise_bonus;
    prob *= p.facing_raise_tight_mul;
    return u(rng) < std::clamp(prob, 0.0, 0.55);
}

bool bot_wants_open_bet_postflop_p(const BotParams &p, double hand_strength01, std::mt19937 &rng)
{
    std::uniform_real_distribution<double> u(0.0, 1.0);
    const double h = std::clamp(hand_strength01, 0.0, 1.0);
    double prob = 0.06 + 0.45 * h;
    prob += p.open_bet_bonus;
    prob *= p.open_bet_tight_mul;
    return u(rng) < std::clamp(prob, 0.0, 0.65);
}

bool bot_bb_check_or_raise_p(const BotParams &p, double range_weight, std::mt19937 &rng)
{
    std::uniform_real_distribution<double> u(0.0, 1.0);
    const double w = std::clamp(range_weight, 0.0, 1.0);
    double prob = 0.12 + 0.4 * w;
    prob += p.bb_checkraise_bonus;
    prob *= p.bb_checkraise_tight_mul;
    return u(rng) < std::clamp(prob, 0.0, 0.7);
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
    case BotStrategy::GTOHeuristic:
        return "GTO (heuristic)";
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
    case BotStrategy::GTOHeuristic:
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
    o << "Preflop exponent: " << p.preflop_exponent << "\n";
    o << "  Each hole combo has a chart weight w in [0,1]. The bot continues preflop with "
         "probability w^exponent (random trial), so low-weight cells fold more often when the "
         "exponent is high.\n\n";

    o << "Postflop exponent: " << p.postflop_exponent << "\n";
    o << "  Uses estimated hand strength h in [0,1]; continue chance is h^exponent.\n\n";

    o << "Facing raise / re-raise (after continuing): bonus " << p.facing_raise_bonus << ", tight × "
      << p.facing_raise_tight_mul << "\n";
    o << "  Base model p = 0.08 + 0.35·m (m = chart weight or hand strength); then p += bonus, p *= tight.\n\n";

    o << "Postflop open raise (checked to): bonus " << p.open_bet_bonus << ", tight × " << p.open_bet_tight_mul
      << "\n";
    o << "  Base p = 0.06 + 0.45·h; then += bonus, *= tight.\n\n";

    o << "BB preflop check-raise: bonus " << p.bb_checkraise_bonus << ", tight × " << p.bb_checkraise_tight_mul
      << "\n";
    o << "  Base p = 0.12 + 0.4·w (w = preflop chart weight); then += bonus, *= tight.\n\n";

    if (s == BotStrategy::GTOHeuristic)
    {
        o << "GTO note: this is a tunable frequency heuristic inspired by balanced play — not a full "
             "Nash equilibrium solver. Adjust exponents and bonuses to study how ranges respond; "
             "use dedicated tools (Pio, GTO+, etc.) for street-by-street equilibrium solutions.\n\n";
    }

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
    case BotStrategy::GTOHeuristic:
        o << "  99+, AKs, AKo, AQs, AQo, AJs, ATs, A9s, KQs, KJs, KTs, QJs, QTs, JTs, T9s, 98s, "
             "87s, 76s, 65s\n";
        break;
    default:
        o << "  (unspecified)\n";
        break;
    }

    o << "\nPreset archetype aggression (editable per seat in Bots & ranges):\n";
    switch (s)
    {
    case BotStrategy::AlwaysCall:
        o << "  No open raises or barrels; always calls when continuing.";
        break;
    case BotStrategy::Maniac:
    case BotStrategy::LooseAggressive:
        o << "  Higher bonuses / full tight multipliers — more barrels and BB raises.";
        break;
    case BotStrategy::Nit:
    case BotStrategy::Rock:
        o << "  Low tight multipliers — fewer semi-bluffs and raises without strength.";
        break;
    case BotStrategy::TightAggressive:
    case BotStrategy::Balanced:
    case BotStrategy::GTOHeuristic:
        o << "  Moderate defaults; GTO preset starts between nit and aggro — tune to taste.";
        break;
    case BotStrategy::LoosePassive:
        o << "  Wide preflop chart but lower open/raise bonuses in the preset.";
        break;
    default:
        o << "  Default aggression profile.";
        break;
    }
    o << "\n";

    return o.str();
}
