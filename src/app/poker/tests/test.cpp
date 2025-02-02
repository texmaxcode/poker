#define BOOST_TEST_MODULE PokerSimulatorTests
#include <boost/test/unit_test.hpp>

#include "poker.hpp"
#include "player.hpp"

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
  for (int i=1; i<=52; ++i) {
    std::cout << "#" << i << " " << deck.get_card() << std::endl;
  }
}

BOOST_AUTO_TEST_CASE(test_that_player_can_hold_two_hold_cards) {
  card_deck deck;
  auto first_card = deck.get_card();
  auto second_card = deck.get_card();
  auto third_card = deck.get_card();
  auto fourth_card = deck.get_card();

  player player_one;
  player player_two;

  player_one.take_hold_cards(first_card, second_card);
  player_two.take_hold_cards(third_card, fourth_card);

  BOOST_CHECK(player_one.first_card == first_card);
  BOOST_CHECK(player_one.second_card == second_card);
  BOOST_CHECK(player_two.first_card == third_card);
  BOOST_CHECK(player_two.second_card == fourth_card);

  player player_three{third_card, fourth_card};
  player player_four{second_card, first_card};

  BOOST_CHECK(player_three.first_card == third_card);
  BOOST_CHECK(player_three.second_card == fourth_card);
  BOOST_CHECK(player_four.first_card == second_card);
  BOOST_CHECK(player_four.second_card == first_card);
}

BOOST_AUTO_TEST_SUITE_END()
