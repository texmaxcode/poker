#include <boost/test/unit_test.hpp>

#include <QCoreApplication>
#include <QDir>
#include <QString>
#include <QTemporaryFile>
#include <QVariantList>
#include <QVariantMap>

#include "bot.hpp"
#include "game.hpp"
#include "hand_history_query.hpp"
#include "persist_sqlite.hpp"

BOOST_AUTO_TEST_SUITE(HAND_HISTORY)

namespace {

void ensureQtApp()
{
  static int qtArgc = 1;
  static char qtArg0[] = "Test_poker_hand_history";
  static char *qtArgv[] = {qtArg0, nullptr};
  if (QCoreApplication::instance() == nullptr)
  {
    new QCoreApplication(qtArgc, qtArgv);
    QCoreApplication::setOrganizationName(QStringLiteral("TexasHoldemGym"));
    QCoreApplication::setApplicationName(QStringLiteral("Texas Hold'em Gym"));
  }
}

} // namespace

BOOST_AUTO_TEST_CASE(played_hand_is_recorded_and_queryable)
{
  ensureQtApp();

  AppStateSqlite::resetForTesting();

  QTemporaryFile tmp(QDir::tempPath() + QStringLiteral("/poker_history_XXXXXX.sqlite"));
  tmp.setAutoRemove(true);
  BOOST_REQUIRE(tmp.open());
  const QString dbPath = tmp.fileName();
  tmp.close();

  qputenv("TEXAS_HOLDEM_GYM_SQLITE", dbPath.toUtf8());
  AppStateSqlite::init();
  BOOST_REQUIRE(AppStateSqlite::sqliteHandle() != nullptr);

  {
    game g;
    g.setInteractiveHuman(false);
    g.setAutoHandLoop(false);
    g.setBotActionDelayEnabled(false);
    g.configure(1, 3, 9, 100);
    g.start();
  }

  HandHistoryQuery q;
  BOOST_REQUIRE_EQUAL(q.countHands(), 1);

  const QVariantList recent = q.listRecent(10, 0);
  BOOST_REQUIRE_EQUAL(recent.size(), 1);
  const QVariantMap row = recent.at(0).toMap();
  BOOST_CHECK_GT(row.value(QStringLiteral("id")).toLongLong(), 0);
  BOOST_CHECK_GT(row.value(QStringLiteral("startedMs")).toLongLong(), 0);
  BOOST_CHECK_EQUAL(row.value(QStringLiteral("sbSize")).toInt(), 1);
  BOOST_CHECK_EQUAL(row.value(QStringLiteral("bbSize")).toInt(), 3);
  BOOST_CHECK_EQUAL(row.value(QStringLiteral("numPlayers")).toInt(), 6);
  BOOST_CHECK_GT(row.value(QStringLiteral("actionCount")).toInt(), 0);

  const qint64 handId = row.value(QStringLiteral("id")).toLongLong();
  const QVariantMap detail = q.hand(handId);
  BOOST_REQUIRE(!detail.isEmpty());
  const QVariantList actions = detail.value(QStringLiteral("actions")).toList();
  BOOST_CHECK_GE(actions.size(), 2); // at least SB + BB posts

  const QVariantMap first = actions.at(0).toMap();
  const QVariantMap second = actions.at(1).toMap();
  BOOST_CHECK(first.value(QStringLiteral("isBlind")).toBool());
  BOOST_CHECK(second.value(QStringLiteral("isBlind")).toBool());

  q.clearAll();
  BOOST_CHECK_EQUAL(q.countHands(), 0);

  AppStateSqlite::resetForTesting();
  qunsetenv("TEXAS_HOLDEM_GYM_SQLITE");
}

BOOST_AUTO_TEST_CASE(factory_reset_clears_hands_and_zeroes_bankrolls)
{
  ensureQtApp();

  AppStateSqlite::resetForTesting();

  QTemporaryFile tmp(QDir::tempPath() + QStringLiteral("/poker_factory_reset_XXXXXX.sqlite"));
  tmp.setAutoRemove(true);
  BOOST_REQUIRE(tmp.open());
  const QString dbPath = tmp.fileName();
  tmp.close();

  qputenv("TEXAS_HOLDEM_GYM_SQLITE", dbPath.toUtf8());
  AppStateSqlite::init();
  BOOST_REQUIRE(AppStateSqlite::sqliteHandle() != nullptr);

  game g;
  g.loadPersistedSettings();
  g.setInteractiveHuman(false);
  g.setAutoHandLoop(false);
  g.setBotActionDelayEnabled(false);
  g.configure(1, 3, 9, 100);
  g.start();

  HandHistoryQuery q;
  BOOST_REQUIRE_EQUAL(q.countHands(), 1);

  g.factoryResetToDefaultsAndClearHistory();
  BOOST_CHECK_EQUAL(q.countHands(), 0);
  BOOST_CHECK_EQUAL(g.seatWallet(0), 0);
  BOOST_CHECK_EQUAL(g.table[static_cast<size_t>(0)].stack, 0);
  BOOST_CHECK_EQUAL(g.seatStrategyIndex(1), static_cast<int>(BotStrategy::GTOHeuristic));
  BOOST_CHECK_EQUAL(g.seatStrategyIndex(0), static_cast<int>(BotStrategy::AlwaysCall));

  AppStateSqlite::resetForTesting();
  qunsetenv("TEXAS_HOLDEM_GYM_SQLITE");
}

BOOST_AUTO_TEST_SUITE_END()
