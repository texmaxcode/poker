#include <boost/test/unit_test.hpp>

#include <cstdint>
#include <random>

#include "bot.hpp"
#include "range_matrix.hpp"

namespace {

double empirical_preflop_continue_rate(const BotParams &p, double range_weight, std::uint64_t seed, int trials)
{
  std::mt19937 rng(static_cast<std::mt19937::result_type>(seed));
  int ok = 0;
  for (int i = 0; i < trials; ++i)
  {
    if (bot_preflop_continue_p(p, range_weight, rng))
      ++ok;
  }
  return static_cast<double>(ok) / static_cast<double>(trials);
}

double empirical_postflop_continue_rate(const BotParams &p, double hand_strength01, std::uint64_t seed,
                                       int trials)
{
  std::mt19937 rng(static_cast<std::mt19937::result_type>(seed));
  int ok = 0;
  for (int i = 0; i < trials; ++i)
  {
    if (bot_postflop_continue_p(p, hand_strength01, rng))
      ++ok;
  }
  return static_cast<double>(ok) / static_cast<double>(trials);
}

bool range_matrix_has_positive_cell(const RangeMatrix &m)
{
  for (int r = 0; r < 13; ++r)
    for (int c = 0; c < 13; ++c)
      if (m.cell(r, c) > 0.0)
        return true;
  return false;
}

} // namespace

BOOST_AUTO_TEST_SUITE(BOT_DECISIONS)

BOOST_AUTO_TEST_CASE(test_bot_preflop_continue_probability_range)
{
  const BotParams p = params_for(BotStrategy::AlwaysCall);
  const int trials = 4000;
  for (double w : {0.0, 0.5, 1.0})
  {
    const double rate = empirical_preflop_continue_rate(p, w, 12345u, trials);
    BOOST_CHECK_GE(rate, 0.0);
    BOOST_CHECK_LE(rate, 1.0);
  }
}

BOOST_AUTO_TEST_CASE(test_bot_postflop_continue_probability_range)
{
  const BotParams p = params_for(BotStrategy::AlwaysCall);
  const int trials = 4000;
  for (double s : {0.0, 0.5, 1.0})
  {
    const double rate = empirical_postflop_continue_rate(p, s, 54321u, trials);
    BOOST_CHECK_GE(rate, 0.0);
    BOOST_CHECK_LE(rate, 1.0);
  }
}

BOOST_AUTO_TEST_CASE(test_fill_preset_range_not_empty)
{
  for (int i = 0; i < static_cast<int>(BotStrategy::Count); ++i)
  {
    RangeMatrix m;
    fill_preset_range(m, static_cast<BotStrategy>(i));
    BOOST_CHECK_MESSAGE(range_matrix_has_positive_cell(m), "strategy index " << i << " produced an empty range");
  }
}

BOOST_AUTO_TEST_CASE(test_params_for_all_strategies)
{
  for (int i = 0; i < static_cast<int>(BotStrategy::Count); ++i)
  {
    const BotStrategy s = static_cast<BotStrategy>(i);
    const BotParams p = params_for(s);
    if (s == BotStrategy::AlwaysCall)
    {
      BOOST_CHECK_GE(p.preflop_exponent, 0.0);
      BOOST_CHECK_GE(p.postflop_exponent, 0.0);
    }
    else
    {
      BOOST_CHECK_GT(p.preflop_exponent, 0.0);
      BOOST_CHECK_GT(p.postflop_exponent, 0.0);
    }
  }
}

BOOST_AUTO_TEST_CASE(test_strategy_description_not_empty)
{
  for (int i = 0; i < static_cast<int>(BotStrategy::Count); ++i)
  {
    const std::string d = strategy_description(static_cast<BotStrategy>(i));
    BOOST_CHECK(!d.empty());
  }
}

BOOST_AUTO_TEST_CASE(test_always_call_high_continue)
{
  const BotParams p = params_for(BotStrategy::AlwaysCall);
  const double rate = empirical_preflop_continue_rate(p, 1.0, 99991u, 8000);
  BOOST_CHECK_GT(rate, 0.95);
}

BOOST_AUTO_TEST_SUITE_END()
