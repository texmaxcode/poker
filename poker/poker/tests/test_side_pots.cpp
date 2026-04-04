#include <boost/test/unit_test.hpp>

#include <vector>

#include "holdem_side_pot.hpp"

BOOST_AUTO_TEST_SUITE(SIDE_POTS)

BOOST_AUTO_TEST_CASE(side_pot_three_distinct_contributions)
{
  const std::vector<int> contrib{50, 100, 150};
  std::vector<int> levels;
  std::vector<int> tiers;
  BOOST_CHECK(holdem_nlhe_side_pot_breakdown(contrib, 300, &levels, &tiers));
  BOOST_REQUIRE_EQUAL(tiers.size(), 3u);
  BOOST_CHECK_EQUAL(levels[0], 50);
  BOOST_CHECK_EQUAL(levels[1], 100);
  BOOST_CHECK_EQUAL(levels[2], 150);
  /// Shortest stack layer = main pot (everyone matched 50); then side pots for higher depths.
  BOOST_CHECK_EQUAL(tiers[0], 150);
  BOOST_CHECK_EQUAL(tiers[1], 100);
  BOOST_CHECK_EQUAL(tiers[2], 50);
}

BOOST_AUTO_TEST_CASE(side_pot_sum_must_match_pot)
{
  std::vector<int> levels;
  std::vector<int> tiers;
  BOOST_CHECK(!holdem_nlhe_side_pot_breakdown({10, 20, 20}, 49, &levels, &tiers));
}

BOOST_AUTO_TEST_CASE(side_pot_single_depth_one_physical_pot)
{
  std::vector<int> levels;
  std::vector<int> tiers;
  const std::vector<int> contrib{100, 100, 100};
  BOOST_CHECK(holdem_nlhe_side_pot_breakdown(contrib, 300, &levels, &tiers));
  BOOST_REQUIRE_EQUAL(tiers.size(), 1u);
  BOOST_CHECK_EQUAL(tiers[0], 300);
}

/// High stack folded; two survivors each put 100 — unique levels 100 and 300; orphan 200-chip tier.
BOOST_AUTO_TEST_CASE(side_pot_folded_high_contributor_tiers)
{
  std::vector<int> levels;
  std::vector<int> tiers;
  const std::vector<int> contrib{300, 100, 100};
  BOOST_CHECK(holdem_nlhe_side_pot_breakdown(contrib, 500, &levels, &tiers));
  BOOST_REQUIRE_EQUAL(tiers.size(), 2u);
  BOOST_CHECK_EQUAL(levels[0], 100);
  BOOST_CHECK_EQUAL(levels[1], 300);
  BOOST_CHECK_EQUAL(tiers[0], 300);
  BOOST_CHECK_EQUAL(tiers[1], 200);
}

/// Three-way all-in 100 / 300 / 500: main 300, side 400, side 200 (table-stakes tier build).
BOOST_AUTO_TEST_CASE(nlhe_side_pots_three_stacks_global_poker_example)
{
  const std::vector<int> contrib{100, 300, 500};
  std::vector<NlheSidePotSlice> slices;
  BOOST_CHECK(nlhe_build_side_pot_slices(contrib, 900, &slices));
  BOOST_REQUIRE_EQUAL(slices.size(), 3u);
  BOOST_CHECK_EQUAL(slices[0].amount, 300);
  BOOST_CHECK_EQUAL(slices[0].contribution_threshold, 100);
  BOOST_CHECK_EQUAL(slices[1].amount, 400);
  BOOST_CHECK_EQUAL(slices[1].contribution_threshold, 300);
  BOOST_CHECK_EQUAL(slices[2].amount, 200);
  BOOST_CHECK_EQUAL(slices[2].contribution_threshold, 500);
  BOOST_CHECK_EQUAL(nlhe_effective_stack_chips(100, 300), 100);
}

BOOST_AUTO_TEST_SUITE_END()
