#include <boost/test/unit_test.hpp>

#include <QCoreApplication>
#include <QDir>
#include <QString>
#include <QTemporaryFile>

#include "persist_sqlite.hpp"
#include "training_store.hpp"

BOOST_AUTO_TEST_SUITE(TRAINING_STORE)

namespace {

void ensureQtApp()
{
  static int qtArgc = 1;
  static char qtArg0[] = "Test_poker_training_store";
  static char *qtArgv[] = {qtArg0, nullptr};
  if (QCoreApplication::instance() == nullptr)
  {
    new QCoreApplication(qtArgc, qtArgv);
    QCoreApplication::setOrganizationName(QStringLiteral("TexasHoldemGym"));
    QCoreApplication::setApplicationName(QStringLiteral("Texas Hold'em Gym"));
  }
}

} // namespace

BOOST_AUTO_TEST_CASE(trainer_timing_setters_clamp)
{
  ensureQtApp();
  AppStateSqlite::resetForTesting();

  QTemporaryFile tmp(QDir::tempPath() + QStringLiteral("/poker_training_XXXXXX.sqlite"));
  tmp.setAutoRemove(true);
  BOOST_REQUIRE(tmp.open());
  const QString dbPath = tmp.fileName();
  tmp.close();

  qputenv("TEXAS_HOLDEM_GYM_SQLITE", dbPath.toUtf8());
  AppStateSqlite::init();
  BOOST_REQUIRE(AppStateSqlite::sqliteHandle() != nullptr);

  TrainingStore store;
  store.setTrainerAutoAdvanceMs(50);
  BOOST_CHECK_EQUAL(store.trainerAutoAdvanceMs(), 500);
  store.setTrainerAutoAdvanceMs(200000);
  BOOST_CHECK_EQUAL(store.trainerAutoAdvanceMs(), 120000);

  store.setTrainerDecisionSeconds(1);
  BOOST_CHECK_EQUAL(store.trainerDecisionSeconds(), 5);
  store.setTrainerDecisionSeconds(999);
  BOOST_CHECK_EQUAL(store.trainerDecisionSeconds(), 120);

  const QVariantMap p = store.loadProgress();
  BOOST_CHECK(p.contains(QStringLiteral("totalDecisions")));

  AppStateSqlite::resetForTesting();
  qunsetenv("TEXAS_HOLDEM_GYM_SQLITE");
}

BOOST_AUTO_TEST_SUITE_END()
