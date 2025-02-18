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
  auto second_card = deck.get_card();

  BOOST_CHECK(first_card != second_card);
}

BOOST_AUTO_TEST_CASE(print_deck_contents_to_output_stream)
{
  card_deck deck;

  for (int i = 1; i <= 52; ++i)
  {
    std::cout << "#" << i << " " << deck.get_card() << std::endl;
  }
}

BOOST_AUTO_TEST_CASE(test_that_player_can_hold_two_hold_cards)
{
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
}

BOOST_AUTO_TEST_CASE(test_player_with_cards_constructor)
{
  card_deck deck;

  auto first_card = deck.get_card();
  auto second_card = deck.get_card();
  auto third_card = deck.get_card();
  auto fourth_card = deck.get_card();

  player player_three{third_card, fourth_card};
  player player_four{second_card, first_card};

  BOOST_CHECK(player_three.first_card == third_card);
  BOOST_CHECK(player_three.second_card == fourth_card);
  BOOST_CHECK(player_four.first_card == second_card);
  BOOST_CHECK(player_four.second_card == first_card);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_be_created)
{

  game game;
  BOOST_CHECK_EQUAL(game.players_count(), 2);
  BOOST_CHECK_EQUAL(game.is_game_in_progress(), false);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_started)
{
  game game;
  game.start();
  BOOST_CHECK_EQUAL(game.players_count(), 2);
  BOOST_CHECK_EQUAL(game.is_game_in_progress(), true);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_collect_blinds)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  game.collect_blinds();
  // TODO: Ugly stuff -- fix it.
  BOOST_CHECK_EQUAL(game.table[0].stack, 97);
  BOOST_CHECK_EQUAL(game.table[1].stack, 99);
  BOOST_CHECK_EQUAL(game.pot, 4);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_take_bets)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  game.collect_blinds();
  // TODO: Ugly stuff -- fix it.
  BOOST_CHECK_EQUAL(game.table[0].stack, 97);
  BOOST_CHECK_EQUAL(game.table[1].stack, 99);
  BOOST_CHECK_EQUAL(game.pot, 4);
  game.take_bets();
  BOOST_CHECK_EQUAL(game.table[0].stack, 88);
  BOOST_CHECK_EQUAL(game.table[1].stack, 90);
  BOOST_CHECK_EQUAL(game.pot, 22);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_hold_cards)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  card test_card{Rank::ACE, Suite::DIAMONDS};

  game.deal_hold_cards();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.table[0].first_card) == typeid(test_card));
  BOOST_CHECK(typeid(game.table[0].second_card) == typeid(test_card));
  BOOST_CHECK(typeid(game.table[1].first_card) == typeid(test_card));
  BOOST_CHECK(typeid(game.table[1].second_card) == typeid(test_card));
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_flop)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  card test_card{Rank::ACE, Suite::DIAMONDS};

  game.deal_flop();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.flop[0]) == typeid(test_card));
  BOOST_CHECK(typeid(game.flop[1]) == typeid(test_card));
  BOOST_CHECK(typeid(game.flop[2]) == typeid(test_card));
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_turn)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  card test_card{Rank::ACE, Suite::DIAMONDS};

  game.deal_turn();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.turn) == typeid(test_card));
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_river)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  card test_card{Rank::ACE, Suite::DIAMONDS};

  game.deal_river();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.river) == typeid(test_card));
}

BOOST_AUTO_TEST_CASE(test_that_game_can_decide_the_winner)
{
  game game;
  BOOST_CHECK(game.players_count() == 2);

  game.collect_blinds();
  // TODO: Ugly stuff -- fix it.
  BOOST_CHECK_EQUAL(game.table[0].stack, 97);
  BOOST_CHECK_EQUAL(game.table[1].stack, 99);
  BOOST_CHECK_EQUAL(game.pot, 4);
  game.take_bets();
  BOOST_CHECK_EQUAL(game.table[0].stack, 88);
  BOOST_CHECK_EQUAL(game.table[1].stack, 90);
  BOOST_CHECK_EQUAL(game.pot, 22);

  card test_card{Rank::ACE, Suite::DIAMONDS};

  game.deal_hold_cards();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.table[0].first_card) == typeid(test_card));
  BOOST_CHECK(typeid(game.table[0].second_card) == typeid(test_card));
  BOOST_CHECK(typeid(game.table[1].first_card) == typeid(test_card));
  BOOST_CHECK(typeid(game.table[1].second_card) == typeid(test_card));

  game.take_bets();
  BOOST_CHECK_EQUAL(game.table[0].stack, 79);
  BOOST_CHECK_EQUAL(game.table[1].stack, 81);
  BOOST_CHECK_EQUAL(game.pot, 40);

  game.deal_flop();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.flop[0]) == typeid(test_card));
  BOOST_CHECK(typeid(game.flop[1]) == typeid(test_card));
  BOOST_CHECK(typeid(game.flop[2]) == typeid(test_card));

  game.take_bets();
  BOOST_CHECK_EQUAL(game.table[0].stack, 70);
  BOOST_CHECK_EQUAL(game.table[1].stack, 72);
  BOOST_CHECK_EQUAL(game.pot, 58);

  game.deal_turn();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.turn) == typeid(test_card));

  game.take_bets();
  BOOST_CHECK_EQUAL(game.table[0].stack, 61);
  BOOST_CHECK_EQUAL(game.table[1].stack, 63);
  BOOST_CHECK_EQUAL(game.pot, 76);

  game.deal_river();
  // TODO: Those are horrible and pointless, but better than nothing.
  BOOST_CHECK(typeid(game.river) == typeid(test_card));

  game.take_bets();
  BOOST_CHECK_EQUAL(game.table[0].stack, 52);
  BOOST_CHECK_EQUAL(game.table[1].stack, 54);
  BOOST_CHECK_EQUAL(game.pot, 94);
  game.decide_the_payout();
}

BOOST_AUTO_TEST_CASE(test_hand_evaluator) {
  game game;
  std::vector<card> hand;
  hand.push_back({Rank::ACE, Suite::DIAMONDS});
  hand.push_back({Rank::ACE, Suite::HEARTS});
  hand.push_back({Rank::TWO, Suite::HEARTS});
  hand.push_back({Rank::THREE, Suite::SPADES});
  hand.push_back({Rank::NINE, Suite::CLUBS});
  hand.push_back({Rank::JACK, Suite::CLUBS});
  hand.push_back({Rank::SIX, Suite::CLUBS});

  game.evaluator(hand);
}

BOOST_AUTO_TEST_SUITE_END()
