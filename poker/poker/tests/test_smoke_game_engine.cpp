#include <boost/test/unit_test.hpp>

#include <QVariantMap>
#include <QString>
#include <vector>

#include "cards.hpp"
#include "game.hpp"

BOOST_AUTO_TEST_SUITE(SMOKE_GAME_ENGINE)

BOOST_AUTO_TEST_CASE(test_that_game_can_be_created)
{

  game game;
  BOOST_CHECK_EQUAL(game.players_count(), 6);
  BOOST_CHECK_EQUAL(game.is_game_in_progress(), false);
}

/// Default table: button seat 0 — clockwise in index space is `(s + n - 1) % n`, so SB=5, BB=4, UTG=3, first postflop=5.
BOOST_AUTO_TEST_CASE(betting_starts_utg_preflop_and_sb_postflop_full_ring)
{
  game g;
  const QVariantMap a = g.bettingAnchors();
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("sbSeat")).toInt(), 5);
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("bbSeat")).toInt(), 4);
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("preflopFirstSeat")).toInt(), 3);
  BOOST_CHECK_EQUAL(a.value(QStringLiteral("postflopFirstSeat")).toInt(), 5);
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

BOOST_AUTO_TEST_SUITE_END()
