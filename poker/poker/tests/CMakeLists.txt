cmake_minimum_required(VERSION 3.26)

add_executable(Test_poker
  test_main.cpp
  test_smoke_cards_deck_player.cpp
  test_smoke_game_engine.cpp
  test_hand_evaluation.cpp
  test_equity_engine.cpp
  test_range_matrix.cpp
  test_side_pots.cpp
  test_bot_decisions.cpp
  test_persistence_sqlite.cpp
  test_hand_log_store.cpp
  test_hand_history.cpp
  test_training_store.cpp
)

target_link_libraries(Test_poker
    poker
    Boost::unit_test_framework
    Qt${QT_VERSION_MAJOR}::Qml
    SQLite::SQLite3
)

# Single CTest entry runs the full binary; Boost.Test prints each suite/case when log level is set.
add_test(
  NAME poker.unit
  COMMAND Test_poker
    --log_level=test_suite
    --report_level=detailed
    --color_output=true
)
set_tests_properties(poker.unit PROPERTIES TIMEOUT 120)

# Verbose run (manual): ctest -R poker.unit -V
# Or: ./build/poker/poker/tests/Test_poker --log_level=test_suite --report_level=detailed
