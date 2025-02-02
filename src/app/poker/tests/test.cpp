#define BOOST_TEST_MODULE PokerSimulatorTests
#include <boost/test/unit_test.hpp>

#include "poker.hpp"

BOOST_AUTO_TEST_SUITE(SMOKE_TEST_SUITE)

BOOST_AUTO_TEST_CASE(can_create_jack_of_diamonds)
{
  card jack_of_dimonds(Rank::JACK, Suite::DIAMONDS);
  BOOST_CHECK(jack_of_dimonds.rank == Rank::JACK);
  BOOST_CHECK(jack_of_dimonds.suite == Suite::DIAMONDS);
}

BOOST_AUTO_TEST_CASE(can_create_ace_of_hearts)
{
  card ace_of_hearts(Rank::ACE, Suite::HEARTS);
  BOOST_CHECK(ace_of_hearts.rank == Rank::ACE);
  BOOST_CHECK(ace_of_hearts.suite == Suite::HEARTS);
}

BOOST_AUTO_TEST_CASE(compare_ace_of_hears_with_jack_of_diamonds)
{
  card ace_of_hearts{Rank::ACE, Suite::HEARTS};
  card jack_of_diamonds{Rank::JACK, Suite::DIAMONDS};
  BOOST_CHECK(ace_of_hearts > jack_of_diamonds);
  BOOST_CHECK(jack_of_diamonds < ace_of_hearts);
}

BOOST_AUTO_TEST_CASE(check_two_cards_for_equality)
{
  auto first_card = card(Rank::ACE, Suite::SPADES);
  auto second_card = card(Rank::ACE, Suite::HEARTS);
  BOOST_CHECK(first_card == second_card);
}

BOOST_AUTO_TEST_CASE(check_that_you_can_get_a_card_from_a_deck)
{
  card_deck deck;
  auto first_card = deck.get_card();
  std::cout << first_card << std::endl;
  auto second_card = deck.get_card();
  BOOST_CHECK(first_card != second_card);
}

BOOST_AUTO_TEST_CASE(print_deck_contents_to_output_stream)
{
  card_deck deck;
  deck.shuffle();
  for (int i=1; i<=52; ++i) {
    std::cout << "#" << i << " " << deck.get_card() << std::endl;
  }
}

BOOST_AUTO_TEST_SUITE_END()
