#include <boost/test/unit_test.hpp>

#include <QCoreApplication>
#include <QDir>
#include <QString>
#include <QTemporaryFile>

#include <sqlite3.h>

#include "hand_log_store.hpp"
#include "persist_sqlite.hpp"

BOOST_AUTO_TEST_SUITE(HAND_LOG_STORE)

BOOST_AUTO_TEST_CASE(test_hand_log_batch_pragmas_and_bulk_actions)
{
  static int qtArgc = 1;
  static char qtArg0[] = "Test_poker_hand_log";
  static char *qtArgv[] = {qtArg0, nullptr};
  std::unique_ptr<QCoreApplication> qtApp;
  if (QCoreApplication::instance() == nullptr)
  {
    qtApp = std::make_unique<QCoreApplication>(qtArgc, qtArgv);
    QCoreApplication::setOrganizationName(QStringLiteral("TexasHoldemGym"));
    QCoreApplication::setApplicationName(QStringLiteral("Texas Hold'em Gym"));
  }

  AppStateSqlite::resetForTesting();

  QTemporaryFile tmp(QDir::tempPath() + QStringLiteral("/poker_hand_log_XXXXXX.sqlite"));
  tmp.setAutoRemove(true);
  BOOST_REQUIRE(tmp.open());
  const QString dbPath = tmp.fileName();
  tmp.close();

  qputenv("TEXAS_HOLDEM_GYM_SQLITE", dbPath.toUtf8());
  AppStateSqlite::init();
  BOOST_REQUIRE(AppStateSqlite::sqliteHandle() != nullptr);

  sqlite3 *db = AppStateSqlite::sqliteHandle();
  sqlite3_stmt *st = nullptr;
  BOOST_REQUIRE_EQUAL(sqlite3_prepare_v2(db, "PRAGMA journal_mode", -1, &st, nullptr), SQLITE_OK);
  BOOST_REQUIRE_EQUAL(sqlite3_step(st), SQLITE_ROW);
  const char *jm = reinterpret_cast<const char *>(sqlite3_column_text(st, 0));
  BOOST_REQUIRE(jm != nullptr);
  BOOST_CHECK(QString::fromUtf8(jm).compare(QStringLiteral("wal"), Qt::CaseInsensitive) == 0);
  sqlite3_finalize(st);

  HandLogBatch batch;
  BOOST_REQUIRE(batch.isActive());

  const qint64 p1 = batch.upsertPlayerByKey(900001, 1'700'000'000'000LL);
  const qint64 p2 = batch.upsertPlayerByKey(900002, 1'700'000'000'000LL);
  BOOST_CHECK_GT(p1, 0);
  BOOST_CHECK_GT(p2, 0);

  const qint64 handId =
      batch.insertHand(1'700'000'001'000LL,
                       1'700'000'002'000LL,
                       42,
                       0,
                       1,
                       2,
                       6,
                       1,
                       2,
                       -1,
                       -1,
                       -1,
                       -1,
                       -1,
                       0);
  BOOST_CHECK_GT(handId, 0);

  constexpr int kRows = 800;
  for (int i = 0; i < kRows; ++i)
  {
    const qint64 pid = (i % 2 == 0) ? p1 : p2;
    batch.insertAction(handId,
                       i,
                       pid,
                       HandLogStreet::kPreflop,
                       HandLogAction::kCall,
                       2,
                       2,
                       i);
  }
  batch.commit();

  BOOST_REQUIRE_EQUAL(sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM actions WHERE hand_id = ?", -1, &st, nullptr),
                      SQLITE_OK);
  sqlite3_bind_int64(st, 1, static_cast<sqlite3_int64>(handId));
  BOOST_REQUIRE_EQUAL(sqlite3_step(st), SQLITE_ROW);
  BOOST_CHECK_EQUAL(sqlite3_column_int64(st, 0), static_cast<sqlite3_int64>(kRows));
  sqlite3_finalize(st);

  AppStateSqlite::resetForTesting();
  qunsetenv("TEXAS_HOLDEM_GYM_SQLITE");
}

BOOST_AUTO_TEST_SUITE_END()
