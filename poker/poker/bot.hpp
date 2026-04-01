#ifndef TEXAS_HOLDEM_GYM_BOT_H
#define TEXAS_HOLDEM_GYM_BOT_H

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
    /// Frequency-shaped “solver-like” heuristic — not a full Nash solver; tunable like other archetypes.
    GTOHeuristic,
    Count
};

/// All engine knobs for a seat: chart weights use exponents; aggression uses bonus + tightness multipliers
/// on the base linear models (see `strategy_description`).
struct BotParams
{
    double preflop_exponent = 1.0;
    double postflop_exponent = 1.0;
    /// Added to base raise/re-raise probability after continuing.
    double facing_raise_bonus = 0.0;
    /// Multiplies that probability (nit-style < 1).
    double facing_raise_tight_mul = 1.0;
    /// Postflop probe / open when checked to.
    double open_bet_bonus = 0.0;
    double open_bet_tight_mul = 1.0;
    /// BB preflop check-raise heuristic.
    double bb_checkraise_bonus = 0.0;
    double bb_checkraise_tight_mul = 1.0;
};

BotParams params_for(BotStrategy s);

bool bot_preflop_continue_p(const BotParams &p, double range_weight, std::mt19937 &rng);
bool bot_postflop_continue_p(const BotParams &p, double hand_strength01, std::mt19937 &rng);
bool bot_wants_raise_after_continue_p(const BotParams &p, double metric01, std::mt19937 &rng);
bool bot_wants_open_bet_postflop_p(const BotParams &p, double hand_strength01, std::mt19937 &rng);
bool bot_bb_check_or_raise_p(const BotParams &p, double range_weight, std::mt19937 &rng);

const char *bot_strategy_name(BotStrategy s);

/// Default 13×13 weights for this archetype (invoked when a seat’s bot type is chosen).
void fill_preset_range(RangeMatrix &m, BotStrategy s);

/// Multi-line description: tuning exponents, default chart, and aggression profile.
std::string strategy_description(BotStrategy s);

#endif // TEXAS_HOLDEM_GYM_BOT_H
