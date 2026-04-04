#include <boost/test/unit_test.hpp>

#include <QByteArray>
#include <QCoreApplication>
#include <QDir>
#include <QString>
#include <QTemporaryFile>
#include <QVariant>
#include <QVariantList>

#include <limits>
#include <memory>

#include "game.hpp"
#include "persist_sqlite.hpp"

BOOST_AUTO_TEST_SUITE(PERSISTENCE_SQLITE)

BOOST_AUTO_TEST_CASE(test_variant_to_json_int)
{
  QVariant out;
  const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(42));
  BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
  BOOST_CHECK_EQUAL(out.toInt(), 42);
}

BOOST_AUTO_TEST_CASE(test_variant_to_json_double)
{
  QVariant out;
  const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(3.14));
  BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
  BOOST_CHECK_CLOSE(out.toDouble(), 3.14, 1e-9);
}

BOOST_AUTO_TEST_CASE(test_variant_to_json_bool)
{
  for (bool b : {true, false})
  {
    QVariant out;
    const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(b));
    BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
    BOOST_CHECK_EQUAL(out.toBool(), b);
  }
}

BOOST_AUTO_TEST_CASE(test_variant_to_json_string)
{
  const QString strings[] = {QString(), QStringLiteral("AA AKs QQ+"), QStringLiteral("hello")};
  for (const QString &s : strings)
  {
    QVariant out;
    const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(s));
    BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
    BOOST_CHECK(out.toString() == s);
  }
}

BOOST_AUTO_TEST_CASE(test_variant_to_json_list)
{
  QVariantList list;
  list << 1 << 2 << 3;
  QVariant out;
  const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(list));
  BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
  const QVariantList got = out.toList();
  BOOST_REQUIRE_EQUAL(got.size(), list.size());
  for (int i = 0; i < list.size(); ++i)
    BOOST_CHECK_EQUAL(got.at(i).toInt(), list.at(i).toInt());
}

BOOST_AUTO_TEST_CASE(test_variant_to_json_string_not_number)
{
  QVariant out;
  const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(QString()));
  BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
  BOOST_CHECK(out.toString().isEmpty());
  BOOST_CHECK_EQUAL(out.typeId(), QMetaType::QString);
}

BOOST_AUTO_TEST_CASE(test_variant_to_json_nan)
{
  QVariant out;
  const double nanv = std::numeric_limits<double>::quiet_NaN();
  const QByteArray json = AppStateSqlite::testVariantToJson(QVariant(nanv));
  BOOST_CHECK(std::string(json.constData(), static_cast<std::size_t>(json.size())) == "0");
  BOOST_REQUIRE(AppStateSqlite::testJsonToVariant(json, &out));
  BOOST_CHECK_EQUAL(out.toDouble(), 0.0);
}

/// Bankroll history + stakes survive a save/load round-trip when the app store is open.
BOOST_AUTO_TEST_CASE(test_bankroll_survives_save_load)
{
  /// `game::loadPersistedSettings` / persistence assume a `QCoreApplication` exists (same as `main.cpp`).
  static int qtArgc = 1;
  static char qtArg0[] = "Test_poker";
  static char *qtArgv[] = {qtArg0, nullptr};
  std::unique_ptr<QCoreApplication> qtApp;
  if (QCoreApplication::instance() == nullptr)
  {
    qtApp = std::make_unique<QCoreApplication>(qtArgc, qtArgv);
    QCoreApplication::setOrganizationName(QStringLiteral("TexasHoldemGym"));
    QCoreApplication::setApplicationName(QStringLiteral("Texas Hold'em Gym"));
  }

  QTemporaryFile tmp(QDir::tempPath() + QStringLiteral("/poker_bankroll_persist_XXXXXX.sqlite"));
  tmp.setAutoRemove(true);
  BOOST_REQUIRE(tmp.open());
  const QString dbPath = tmp.fileName();
  tmp.close();

  qputenv("TEXAS_HOLDEM_GYM_SQLITE", dbPath.toUtf8());
  AppStateSqlite::init();
  BOOST_REQUIRE(AppStateSqlite::isOpen());
  /// `init()` migrates an empty DB from legacy QSettings — clear `v1/` so this test is isolated.
  AppStateSqlite::removeKeysWithPrefix(QStringLiteral("v1/"));
  AppStateSqlite::sync();

  game g;
  g.loadPersistedSettings();
  g.configure(1, 2, 2, 100);
  /// `configure` seeds one snapshot; each `setSeatBankrollTotal` records another (total = stack + wallet).
  g.setSeatBankrollTotal(0, 150);
  g.setSeatBankrollTotal(0, 130);
  g.savePersistedSettings();

  const int snapshotsBefore = g.bankrollSnapshotCount();
  BOOST_CHECK_GE(snapshotsBefore, 3);

  game g2;
  g2.loadPersistedSettings();

  if (!AppStateSqlite::isOpen())
  {
    /// No backing store — `savePersistedSettings` / `loadPersistedSettings` are no-ops; still must not crash.
    return;
  }

  BOOST_CHECK_EQUAL(g2.configuredSmallBlind(), 1);
  BOOST_CHECK_EQUAL(g2.configuredBigBlind(), 2);
  BOOST_CHECK_EQUAL(g2.configuredStreetBet(), 2);
  BOOST_CHECK_EQUAL(g2.configuredStartStack(), 100);
  BOOST_CHECK_EQUAL(g2.bankrollSnapshotCount(), snapshotsBefore);

  const QVariantList series = g2.bankrollSeries(0);
  BOOST_REQUIRE(!series.isEmpty());
  BOOST_CHECK_EQUAL(series.last().toInt(), 130);
}

BOOST_AUTO_TEST_SUITE_END()
