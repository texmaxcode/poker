#define BOOST_TEST_MODULE PokerSimulatorTests
#include <boost/test/unit_test.hpp>

#include "poker_simulator.hpp"

BOOST_AUTO_TEST_SUITE(SMOKE_TEST_SUITE)

BOOST_AUTO_TEST_CASE(MakeSureThatVersionIsAvalable)
{
  simulator studio;
  BOOST_CHECK(QString{"0.0.1"} == studio.get_version());
}

BOOST_AUTO_TEST_SUITE_END()
