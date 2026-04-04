#include <boost/test/unit_test.hpp>

#include <string>
#include <vector>

#include "cards.hpp"
#include "game.hpp"
#include "hand_eval.hpp"

BOOST_AUTO_TEST_SUITE(HAND_EVALUATION)

BOOST_AUTO_TEST_CASE(test_hand_evaluator)
{
  game game;
  std::vector<card> hand;
  hand.push_back({Rank::ACE, Suite::DIAMONDS});
  hand.push_back({Rank::ACE, Suite::HEARTS});
  hand.push_back({Rank::TWO, Suite::HEARTS});
  hand.push_back({Rank::THREE, Suite::SPADES});
  hand.push_back({Rank::NINE, Suite::CLUBS});
  hand.push_back({Rank::JACK, Suite::CLUBS});
  hand.push_back({Rank::SIX, Suite::CLUBS});

  const std::string desc = game.evaluator(hand);
  BOOST_CHECK(desc.find("Pair") != std::string::npos || desc.find("pair") != std::string::npos);
}

BOOST_AUTO_TEST_CASE(pair_beats_high_card_seven_cards)
{
  std::vector<card> pair_hand{
      {Rank::KING, Suite::HEARTS}, {Rank::KING, Suite::DIAMONDS}, {Rank::TWO, Suite::CLUBS},
      {Rank::FOUR, Suite::SPADES}, {Rank::SIX, Suite::HEARTS}, {Rank::EIGHT, Suite::DIAMONDS},
      {Rank::TEN, Suite::CLUBS}};
  std::vector<card> ace_high{
      {Rank::ACE, Suite::SPADES}, {Rank::KING, Suite::CLUBS}, {Rank::QUEEN, Suite::HEARTS},
      {Rank::JACK, Suite::DIAMONDS}, {Rank::NINE, Suite::CLUBS}, {Rank::SEVEN, Suite::SPADES},
      {Rank::FIVE, Suite::HEARTS}};
  BOOST_CHECK(compare_holdem_hands(pair_hand, ace_high) > 0);
}

BOOST_AUTO_TEST_CASE(straight_beats_three_of_a_kind)
{
  std::vector<card> straight{
      {Rank::TEN, Suite::HEARTS}, {Rank::JACK, Suite::DIAMONDS}, {Rank::QUEEN, Suite::CLUBS},
      {Rank::KING, Suite::SPADES}, {Rank::ACE, Suite::HEARTS}, {Rank::TWO, Suite::DIAMONDS},
      {Rank::THREE, Suite::CLUBS}};
  std::vector<card> trips{
      {Rank::SEVEN, Suite::HEARTS}, {Rank::SEVEN, Suite::DIAMONDS}, {Rank::SEVEN, Suite::CLUBS},
      {Rank::TWO, Suite::SPADES}, {Rank::FOUR, Suite::HEARTS}, {Rank::NINE, Suite::DIAMONDS},
      {Rank::JACK, Suite::CLUBS}};
  BOOST_CHECK(compare_holdem_hands(straight, trips) > 0);
}

BOOST_AUTO_TEST_CASE(royal_flush_beats_lower_straight_flush)
{
  std::vector<card> royal{
      {Rank::ACE, Suite::SPADES}, {Rank::KING, Suite::SPADES}, {Rank::QUEEN, Suite::SPADES},
      {Rank::JACK, Suite::SPADES}, {Rank::TEN, Suite::SPADES}, {Rank::TWO, Suite::HEARTS},
      {Rank::THREE, Suite::DIAMONDS}};
  std::vector<card> nine_high_sf{
      {Rank::NINE, Suite::HEARTS}, {Rank::EIGHT, Suite::HEARTS}, {Rank::SEVEN, Suite::HEARTS},
      {Rank::SIX, Suite::HEARTS}, {Rank::FIVE, Suite::HEARTS}, {Rank::KING, Suite::CLUBS},
      {Rank::ACE, Suite::DIAMONDS}};
  BOOST_CHECK(compare_holdem_hands(royal, nine_high_sf) > 0);
}

BOOST_AUTO_TEST_CASE(identical_best_five_chops)
{
  // Same seven cards in different order → same best five → chop.
  std::vector<card> a{
      {Rank::ACE, Suite::SPADES}, {Rank::KING, Suite::CLUBS}, {Rank::QUEEN, Suite::HEARTS},
      {Rank::JACK, Suite::DIAMONDS}, {Rank::TEN, Suite::CLUBS}, {Rank::TWO, Suite::SPADES},
      {Rank::THREE, Suite::HEARTS}};
  std::vector<card> b = a;
  std::swap(b[0], b[1]);
  BOOST_CHECK_EQUAL(compare_holdem_hands(a, b), 0);
}

BOOST_AUTO_TEST_SUITE_END()
