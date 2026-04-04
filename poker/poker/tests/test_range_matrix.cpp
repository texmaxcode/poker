#include <boost/test/unit_test.hpp>

#include "cards.hpp"
#include "range_matrix.hpp"

BOOST_AUTO_TEST_SUITE(RANGE_MATRIX)

BOOST_AUTO_TEST_CASE(range_text_parses_aa_and_aks)
{
  RangeMatrix m;
  BOOST_REQUIRE(m.parse_text("AA,AKs"));
  const card ah{Rank::ACE, Suite::HEARTS};
  const card ad{Rank::ACE, Suite::DIAMONDS};
  const card kh{Rank::KING, Suite::HEARTS};
  BOOST_CHECK_GT(m.weight(ah, ad), 0.9);
  BOOST_CHECK_GT(m.weight(ah, kh), 0.9);
}

BOOST_AUTO_TEST_CASE(range_text_accepts_space_separated_tokens)
{
  RangeMatrix m;
  BOOST_REQUIRE(m.parse_text("AA AKs 98s"));
  const card nine{Rank::NINE, Suite::HEARTS};
  const card eight{Rank::EIGHT, Suite::HEARTS};
  BOOST_CHECK_GT(m.weight(nine, eight), 0.9);
}

BOOST_AUTO_TEST_CASE(range_text_empty_clears_matrix)
{
  RangeMatrix m;
  BOOST_REQUIRE(m.parse_text("AA"));
  BOOST_REQUIRE(m.parse_text(""));
  const card ah{Rank::ACE, Suite::HEARTS};
  const card ad{Rank::ACE, Suite::DIAMONDS};
  BOOST_CHECK_LT(m.weight(ah, ad), 0.1);
}

BOOST_AUTO_TEST_SUITE_END()
