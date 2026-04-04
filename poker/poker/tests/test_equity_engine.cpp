#include <boost/test/unit_test.hpp>

#include <random>

#include "cards.hpp"
#include "equity_engine.hpp"

BOOST_AUTO_TEST_SUITE(EQUITY_ENGINE)

BOOST_AUTO_TEST_CASE(equity_aa_vs_kk_preflop_high)
{
  const card ah{Rank::ACE, Suite::HEARTS};
  const card ad{Rank::ACE, Suite::DIAMONDS};
  const card kh{Rank::KING, Suite::HEARTS};
  const card kd{Rank::KING, Suite::DIAMONDS};
  std::vector<card> board;
  std::mt19937 rng{42};
  const auto er = monte_carlo_equity_vs_hand(ah, ad, board, kh, kd, 8000, rng);
  BOOST_CHECK(er.error.empty());
  BOOST_CHECK_GT(er.equity_hero, 0.78);
  BOOST_CHECK_LT(er.equity_hero, 0.90);
}

BOOST_AUTO_TEST_SUITE_END()
