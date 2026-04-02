#define BOOST_TEST_MODULE PokerSimulatorTests
#include <boost/test/unit_test.hpp>

#include <QString>

#include <vector>

#include "game.hpp"
#include "hand_eval.hpp"
#include "range_matrix.hpp"
#include "equity_engine.hpp"

BOOST_AUTO_TEST_SUITE(SMOKE_TEST_SUITE)

BOOST_AUTO_TEST_CASE(can_create_jack_of_diamonds)
{
  card jack_of_diamonds(Rank::JACK, Suite::DIAMONDS);

  BOOST_CHECK(jack_of_diamonds.rank == Rank::JACK);
  BOOST_CHECK(jack_of_diamonds.suite == Suite::DIAMONDS);
}

BOOST_AUTO_TEST_CASE(can_create_ace_of_hearts)
{
  card ace_of_hearts(Rank::ACE, Suite::HEARTS);

  BOOST_CHECK(ace_of_hearts.rank == Rank::ACE);
  BOOST_CHECK(ace_of_hearts.suite == Suite::HEARTS);
}

BOOST_AUTO_TEST_CASE(compare_ace_of_hearts_with_jack_of_diamonds)
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

  BOOST_CHECK(first_card != second_card);
  BOOST_CHECK(same_rank(first_card, second_card));
}

BOOST_AUTO_TEST_CASE(check_that_you_can_get_a_card_from_a_deck)
{
  card_deck deck;

  auto first_card = deck.get_card();
  auto second_card = deck.get_card();

  BOOST_CHECK(first_card != second_card);
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

BOOST_AUTO_TEST_CASE(test_player_hold_cards_assignment)
{
  card_deck deck;

  auto first_card = deck.get_card();
  auto second_card = deck.get_card();
  auto third_card = deck.get_card();
  auto fourth_card = deck.get_card();

  player player_three;
  player_three.take_hold_cards(third_card, fourth_card);
  player player_four;
  player_four.take_hold_cards(second_card, first_card);

  BOOST_CHECK(player_three.first_card == third_card);
  BOOST_CHECK(player_three.second_card == fourth_card);
  BOOST_CHECK(player_four.first_card == second_card);
  BOOST_CHECK(player_four.second_card == first_card);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_be_created)
{

  game game;
  BOOST_CHECK_EQUAL(game.players_count(), 6);
  BOOST_CHECK_EQUAL(game.is_game_in_progress(), false);
}

/// Default table: button seat 0 — UTG is seat 3, SB=1 acts first post-flop (see `action_order` / `bettingAnchors`).
BOOST_AUTO_TEST_CASE(betting_starts_utg_preflop_and_sb_postflop_full_ring)
{
  game g;
  const QVariantMap a = g.bettingAnchors();
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("sbSeat")).toInt(), 1);
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("bbSeat")).toInt(), 2);
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("preflopFirstSeat")).toInt(), 3);
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("postflopFirstSeat")).toInt(), 1);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_started)
{
  game game;
  game.setInteractiveHuman(false);
  game.setAutoHandLoop(false);
  // Otherwise `start()` runs a full hand with ~550 ms per bot action (~20 actions → ~11 s).
  game.setBotActionDelayEnabled(false);
  game.start();
  BOOST_CHECK_EQUAL(game.players_count(), 6);
  // Full automated hand completes in start(); session is idle until the next deal.
  BOOST_CHECK_EQUAL(game.is_game_in_progress(), false);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_collect_blinds)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.collect_blinds();
  BOOST_CHECK_EQUAL(game.pot, 4);
  int sum = 0;
  for (int i = 0; i < 6; ++i)
    sum += game.table[i].stack;
  BOOST_CHECK_EQUAL(sum + game.pot, 600);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_take_bets)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.collect_blinds();
  BOOST_CHECK_EQUAL(game.pot, 4);
  game.take_bets_for_testing();
  BOOST_CHECK_EQUAL(game.pot, 58);
  int sum = 0;
  for (int i = 0; i < 6; ++i)
    sum += game.table[i].stack;
  BOOST_CHECK_EQUAL(sum + game.pot, 600);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_hold_cards)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.deal_hold_cards();
  for (int i = 0; i < 6; ++i)
  {
    BOOST_CHECK(game.table[i].first_card != game.table[i].second_card);
  }
  std::vector<card> all;
  for (int i = 0; i < 6; ++i)
  {
    all.push_back(game.table[i].first_card);
    all.push_back(game.table[i].second_card);
  }
  for (size_t a = 0; a < all.size(); ++a)
    for (size_t b = a + 1; b < all.size(); ++b)
      BOOST_CHECK(all[a] != all[b]);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_flop)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.deal_flop();
  BOOST_CHECK_EQUAL(game.flop.size(), 3);
  BOOST_CHECK(game.flop[0] != game.flop[1]);
  BOOST_CHECK(game.flop[1] != game.flop[2]);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_turn)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.deal_turn();
  BOOST_CHECK(game.turn.rank >= Rank::TWO && game.turn.rank <= Rank::ACE);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_deal_river)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.deal_river();
  BOOST_CHECK(game.river.rank >= Rank::TWO && game.river.rank <= Rank::ACE);
}

BOOST_AUTO_TEST_CASE(test_that_game_can_decide_the_winner)
{
  game game;
  BOOST_CHECK(game.players_count() == 6);

  game.collect_blinds();
  BOOST_CHECK_EQUAL(game.pot, 4);
  game.take_bets_for_testing();
  BOOST_CHECK_EQUAL(game.pot, 58);

  game.deal_hold_cards();

  game.take_bets_for_testing();
  BOOST_CHECK_EQUAL(game.pot, 112);

  game.deal_flop();
  BOOST_CHECK_EQUAL(game.flop.size(), 3);

  game.take_bets_for_testing();
  BOOST_CHECK_EQUAL(game.pot, 166);

  game.deal_turn();

  game.take_bets_for_testing();
  BOOST_CHECK_EQUAL(game.pot, 220);

  game.deal_river();

  game.take_bets_for_testing();
  BOOST_CHECK_EQUAL(game.pot, 274);
  game.decide_the_payout();

  BOOST_CHECK_EQUAL(game.pot, 0);
  int sum = 0;
  for (int i = 0; i < 6; ++i)
    sum += game.table[i].stack;
  BOOST_CHECK_EQUAL(sum, 600);
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

BOOST_AUTO_TEST_SUITE_END()
